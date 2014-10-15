# ParseRobotsTXT.pm
#
# Copyright (C) 2014  Blekko, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

#
# Based on WWW::RobotRules http://search.cpan.org/~gaas/libwww-perl-5.808/lib/WWW/RobotRules.pm
# WWW::RobotRules is part of the standard perl install
# /usr/lib/perl5/vendor_perl/5.8.8/WWW/RobotRules.pm
#
# Extended to honor "Allow:" tags and to parse "*" wildcards in file and directory listings.
#

package ParseRobotsTXT;

use strict;

use String::Utils;
use Data::Dumper;

sub canonical_ua
{
    my($ua) = @_;

    return 'scoutjet' if ($ua =~ /\b(scoutjet|blekkobot)\b/i);

    return lc($ua);
}

# The standard suggests that rules should be interpretted in order they are in listed in the
# robots.txt. This is fine if people whould stick to only using "Disallow:" rules, but adding
# "Allow:" rules makes this non-intitive for the non-programmers creating robots.txt files.
#
# We now default to a more permissive interpretation of rules. This interprets the rules in order,
# but uses the longest (most specific) rule that matches. So if a more specific "Allow:" rule
# follows a more general "Disallow:" rule, we will honor the Allow rule. With the assumption that
# the creator of the file didn't realize that the Allow rule would not, possibly ever, be hit.
#
# This is very similar to what Google does. Google does not publish the exact rules it follows,
# but they do publish an interface for testing your robots.txt.
#
$ParseRobotsTXT::STRICT_RULE_ORDER = 0;

#
# Break the strict interpretation of some rules in order to "do as i mean." Fewer suprises to webmasters.
#   1. count "Crawl-Delay" and "sitemap:" as a rule, allowing these lines appear in "User-Agent" groupings.
#   2. allow blank line in between Allow/Dissalow/User-Agent lines (violates RFC)
#
$ParseRobotsTXT::STRICT = 0;

# print out what rules are firing on a given URL
$ParseRobotsTXT::verbose = 0;

sub parse_robots
{
    my( $robot_txt_uri, $txtp ) = @_;

    my $txt = $$txtp;
    my $hash = {};
    my $crawl_delay = {};
    if (ref $robot_txt_uri ne 'URI::XS') {
        $robot_txt_uri = URI::XS->new("$robot_txt_uri");
    }

    my $seen_rule = 0;   # watch for missing record separators

    my @agents = ();
    my %rules = ();
    my $skip_this_agent = 0;
    my $sitemaps;
    my $lineno = 0;
    my $blankline = 0;

    my $max_size = 100_000;
    if (length($txt) > $max_size) {
        push( @{$hash->{error}},"extremely big robots.txt file, truncating to $max_size.");
        $txt = substr($txt,0,$max_size);
    }

    # Remove unix BOM characters (0xFEFF), aka BYTE ORDER MARKER. This should only appear at
    # the beginning of a file, but sometimes appears in the middle if two files are concatenated
    # If the string is in single byte mode, the BOM is represented by bytes EF BB BF
    if ($txt =~ s/(\x{FEFF}|\x{EF}\x{BB}\x{BF})//g) {
        push( @{$hash->{error}}, "Had to clean up BOM characters in robots.txt");
    }

    # blank lines are significant, so turn CRLF into LF to avoid generating
    # false ones
    $txt =~ s/\015\012/\012/g;

    # split at \012 (LF) or \015 (CR) (Mac text files have just CR for EOL)
    foreach my $line (split(/[\012\015]/, $txt)) {
        # Lines containing only a comment are discarded completely, and
        # therefore do not indicate a record boundary.
        $lineno++;

        next if ($line =~ /^\s*\#/);

        $line =~ s/\s*\#.*//;        # remove comments at end-of-line

        if (length($line) > 2048) {
            # May indicate non-text data such as HTML or binary data.
            push( @{$hash->{error}}, "extremely long line [$lineno] in robots.txt file, this may not be a valid robots.txt. Giving up.");
            last;
        }

        if ($line =~ /^\s*$/) {            # blank line
            if ($ParseRobotsTXT::STRICT) {
                # this is stict mode: blank line terminates the ruleset
                $seen_rule = 0;
                @agents = ();
            }
            $blankline = 1;
        }
        elsif ($line =~ /^\s*Sitemap\s*:\s*(.*)/i) {
            $seen_rule = 1 if (! $ParseRobotsTXT::STRICT);
            $sitemaps->{$1} = 1;
        }
        elsif ($line =~ /^\s*User-Agent\s*:\s*(.*)/i) {
            my $ua = $1;
            $ua =~ s/\s+$//;

            if ($seen_rule) {
                # treat as start of a new record
                $seen_rule = 0;
                @agents = ();
            }

            if ($blankline && scalar(@agents)) {
                push( @{$hash->{error}},
                      "Warning: User-Agent lines separated by blank lines, not RFC complient. line=$lineno");
            }
            $blankline = 0;

            $skip_this_agent = 0;

            push(@agents,lc($ua));
        }
        elsif ($line =~ /^\s*(Disallow|Allow)\s*:\s*(.*)/i) {
            my ($ruletype,$rule) = (lc($1),$2);

            String::Utils::superchomp($rule);

            if ($blankline) {
                # http://www.robotstxt.org/norobots-rfc.txt  section 3.3 Formal Syntax.
                # No blank lines are allowed in the record declaration.

                # http://www.robotstxt.org/robotstxt.html
                #   Note that you need a separate "Disallow" line for
                #   every URL prefix you want to exclude -- you cannot say
                #   "Disallow: /cgi-bin/ /tmp/" on a single line. Also,
                #   you may not have blank lines in a record, as they are
                #   used to delimit multiple records.

                push( @{$hash->{error}},
                      "Warning: $ruletype was preceeded by a blank line, not RFC complient. line=$lineno");
            }

            $blankline = 0;

            if (scalar(@agents) == 0) {
                # we have a rule, without a valid user-agent specified

                push( @{$hash->{error}},
                      "Ignoring [$ruletype] missing preceeding useragent declaration. line=$lineno");
            }

            $seen_rule = 1;
            next if ($skip_this_agent);

            my $r;
            if (length $rule)
            {
                my $u = URI::XS->new_abs( $rule, $robot_txt_uri );

                next if (!$u->abs_is_local($robot_txt_uri));

                $r = $u->path_query;
                $r =~ s/^\/// if ($rule !~ /^\//);
                $r =~ s/\*+$//;     # tailing * don't mean a thing...
                $r = quotemeta($r);
                $r =~ s/\\\*/.*/;
                $r =~ s/\\\$$/\$/;
                $rule = $r;

                if ( length $rule == 0) {
                    next if ($ruletype eq "allow");
                    # "Disallow: "  => "Allow: /"
                    $rule = "/";
                    $ruletype = "allow";
                }
            }

            foreach my $ua (@agents)
            {
                    push( @{ $hash->{rules}->{canonical_ua($ua)} }, [$rule, ($ruletype eq "disallow" ? 0 : 1), $lineno, $line] );
            }
        }
        elsif ($line =~ /^\s*Crawl-delay\s*:\s*(\d+.\d+|\d+)/i)
        {
            my $delay = $1;
            push(@agents,'*') if ( $#agents < 0 );
            foreach my $ua (@agents)
            {
                $crawl_delay->{ canonical_ua($ua) } = $delay;

                if ( $ua eq '*' )
                {
                    $hash->{ 'default-crawl-delay' } = $delay;
                }
            }
            $seen_rule = 1 if (! $ParseRobotsTXT::STRICT);
        }
        elsif ($line =~ /^\s*([A-Za-z\-]+?)\s*:\s*/) {
            # unsupported or extention or typo
            push( @{$hash->{error}}, "Warning: Ignoring unsupported extention [$1] on line $lineno");
            $seen_rule = 1 if (! $ParseRobotsTXT::STRICT);
            $blankline = 0;
        }
    }

    if (defined $sitemaps) {
        $hash->{sitemaps} = [keys %$sitemaps];
    }
    my $banned_ua = {};

    foreach my $ua (keys %{ $hash->{rules} }) {
        my $this_ua_is_banned = 0;
        foreach my $rule (@{ $hash->{rules}->{$ua} }) {
            if ($rule->[1]) {
                $this_ua_is_banned = 0;
                last;
            }
            if ($rule->[0] eq '\\/') {
                $this_ua_is_banned = 1;
            }
        }
        $banned_ua ->{$ua} = 1 if ($this_ua_is_banned);
    }
    $hash ->{'banned_useragents'} = $banned_ua;
    $hash ->{'crawl-delay'} = $crawl_delay;
    return $hash;
}

sub agent_rules
{
    my($hash, $my_ua) = @_;
    return unless $my_ua;
    $my_ua = canonical_ua($my_ua);
    my $rules = $hash->{rules};
    my @uarules = ();
    my $save_line;
    foreach my $ua_line (keys %$rules) {
        next if ($my_ua eq "*");
        $save_line =  quotemeta ($ua_line);
         if ($save_line  =~ /\b$my_ua\b/) {
           #print ("UA ".lc($ua_line)." my_ua ".$my_ua."\n");
           #if(lc($ua_line) eq lc($my_ua)) {
           # return ($rules->{$ua_line},$ua_line) if wantarray;
           # return ($rules->{$ua_line});
           push (@uarules, $rules->{($ua_line)});
      }
    }
    if (!@uarules){
        return ($rules->{'*'},'*') if wantarray;
        return $rules->{'*'};
    }
    my $flat_rule;
    foreach my $rule (@uarules)
    {
        foreach my $single_rule (@$rule)
        {
            push (@$flat_rule, $single_rule);
        }


    }

    return ($flat_rule, $my_ua) if wantarray;
    return ($flat_rule);
}

#
# return true if we ($my_ua) is completely banned by the robots.txt
#
sub banned
{
    my ( $hash, $my_ua ) = @_;

    return unless $my_ua;
    $my_ua = canonical_ua($my_ua);

    return 0 if ( !defined $hash);
    return 0 if ( !keys %$hash );
    my $banned_ua = $hash->{'banned_useragents'};
    if  (defined ($banned_ua))
    {
       if (ref $banned_ua eq 'HASH')
        {
            return 2 if ($banned_ua->{$my_ua});
        }
        elsif (ref $banned_ua eq 'ARRAY')
        {
            return 2 if (grep {$my_ua} @$banned_ua);
        }
    }
    my $rules = agent_rules( $hash, $my_ua );
    return 0 if ( !defined($rules) );
    my $banned = 0;
    for my $ruleset (@{ $rules }) {
        my($rule, $allow) = @$ruleset;
        return 0 if ($allow);
        $banned = 1 if ( $rule eq '/' || $rule eq '\\/');
    }
    return $banned;
}

sub allowed
{
    my($hash, $uri, $my_ua) = @_;
    return unless $my_ua;
    $my_ua = canonical_ua($my_ua);

    return 1 if ( !defined($hash) || !keys %$hash );
    if ( ref $uri eq '' )
    {
        $uri = URI::XS->new($uri);
        return 0 if ( !defined $uri );
    }

    my $str = $uri->path_query;
    my $scheme = $uri->scheme;

    return 1 if ($str eq '/robots.txt');
    return 1 unless $scheme eq 'http' or $scheme eq 'https';

    return 0 if (banned($hash, $my_ua));

    my ($rules,$rule_ua) = agent_rules($hash, $my_ua);

    return 1 if (!defined($rules));

    # print "--- checking [$str] ---\n";
    my $ret = 1;
    my $lineno_match = 0;
    my $line_match   = '';
    my $match_len = 0;
    my $path_len  = 0;
    foreach my $rule (@{$rules}) {
        my($path,$allow,$lineno,$line) = @$rule;
        next if (length $path == 0);   # Disallow: \n == allow all
        $path = "^$path" if ($path =~ /^\\\//);
        # print "Checking rule: $str =~ $path " . ($allow ? "ALLOW" : "DISALLOW") . "\n";
        if ($str =~ /($path)/) {
            print "MATCHED rule: $path " . ($allow ? "ALLOW" : "DISALLOW") . "\n" if ($ParseRobotsTXT::verbose);
            my $match = $1;
            if ($ParseRobotsTXT::STRICT_RULE_ORDER) {
                # Strict interpretation is to evaluate rules in the order they are written, first match wins.
                $ret = $allow;
                $lineno_match = $lineno;
                $line_match   = $line;
                last;
            }
            else {
                # more permissively allow the "best" match to win. Best is defined here as the longest match.
                if ((length($match) > $match_len) ||
                    (length($match) == $match_len) && (length($path) > $path_len))
                {
                    # Use the longest pattern match, in case of a tie the longest rule wins
                    $ret = $allow;
                    $match_len = length($match);
                    $path_len  = length($path);
                    $lineno_match = $lineno;
                    $line_match   = $line;
                }
            }
        }
    }
    return ($ret,$lineno_match,$line_match,$rule_ua) if wantarray;
    return $ret;
}

sub get_delay
{
    my( $hash, $my_ua ) = @_;
    $my_ua = canonical_ua($my_ua);
    $my_ua ||= "*";
    my $delay = $hash->{'crawl-delay'};
    if (ref $delay ne 'HASH')
    {
        return $delay ||$hash->{'default-crawl-delay'} || undef;
    }
    return $delay->{$my_ua} || $hash->{'default-crawl-delay'}|| undef;
}


1;

