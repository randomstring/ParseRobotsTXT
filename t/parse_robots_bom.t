use strict;
use warnings;
use Test::More tests=>28;
use Crawl::URI;
use Crawl::ParseRobotsTXT;
use Data::Dumper;

# Test that Unicode BOM is ignored
# Text lines with \x{nn} will be converted to corresponding character

{
    no warnings 'once';
    $Crawl::URI::ABS_REMOTE_LEADING_DOTS = 1;
}
# $Crawl::ParseRobotsTXT::KEEP_ALL_AGENT_RULES = 1;

my $robotstxt;
my $rh = {};
my $ruri = Crawl::URI->new("http://www.example.com/robots.txt");
my $baseuri = Crawl::URI->new("http://www.example.com/");

my $line;
while($line = <DATA>) {
    $robotstxt = '';
    $rh = {};
    $robotstxt = $line if ($line !~ /^\#/);
    Crawl::ParseRobotsTXT::set_agent("scoutjet");
    while ($line = <DATA>) {
        last if ($line =~ /^\#tests/);
        $robotstxt .= $line;
   }

    # convert any \x{nn} characters
    $robotstxt =~ s/\\x{(.*?)}/chr hex $1/ge;

    $rh = Crawl::ParseRobotsTXT::parse_robots($ruri,\$robotstxt);

    # print Data::Dumper::Dumper($rh);

    while ($line = <DATA>) {
        last if ($line =~ /^\#robots.txt/);
        # Ignore other comments
        next if ($line =~ /^#/);
        chomp($line);
        my($agent,$path,$result) = split (/\s+/,$line,3);

        next if (!defined $path or $path eq '');

        $agent  = '*' if ($agent eq '');
        $result = 1 if ($result =~ /^yes/i);
        $result = 0 if ($result =~ /^no/i);
        my $which = ("DISALLOWED","ALLOWED")[$result];

        my $uri = Crawl::URI->new_abs($path,$baseuri);

        Crawl::ParseRobotsTXT::set_agent($agent);
        my $allow = Crawl::ParseRobotsTXT::allowed($rh,$uri);

        unless (is $allow, $result, "Agent $agent expected $which for $path") {
            print Data::Dumper::Dumper($rh);
        }
    }
}

__DATA__
#robots.txt
#tests
# Everything should be allowed
* /path/ 1
* / 1
* /foo/bar/ 1
* /index.html 1
* /test.cgi?q=test 1
* /test.cgi?q=test#foo 1

#robots.txt
# Just a comment line
#tests
# Everything should be allowed
* /path/ 1
* / 1
* /foo/bar/ 1
* /index.html 1
* /test.cgi?q=test 1
* /test.cgi?q=test#foo 1

#robots.txt
User-agent: *
Disallow: /
#tests
* /path/ 0
* / 0
* /foo/bar/ 0
* /index.html 0
* /test.cgi?q=test 0
* /test.cgi?q=test#foo 0

#robots.txt
#If the BOM character is missed, the User-agent line won't be
#translated, causing it to be treated as User-agent *
\x{feff}User-agent: bomagent
Disallow: /

User-agent: *
Disallow: /foo/
#tests

* /path/ 1
* / 1
* /foo/bar/ 0
* /foo 1
* /index.html 1

#robots.txt
# Repeat the above test using the 3-byte UTF-8 equivalent
# This will happen if the file fetched from the PM without putting it
# into UTF8 string mode
\x{EF}\x{BB}\x{BF}User-agent: bomagent
Disallow: /

User-agent: *
Disallow: /foo/
#tests

* /path/ 1
* / 1
* /foo/bar/ 0
* /foo 1
* /index.html 1


