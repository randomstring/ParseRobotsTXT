use strict;
use warnings;

# Test to see that a missing newline at the end of the file does not break 
# parsing. 

use Test::More qw(no_plan);
use URI::XS;
use ParseRobotsTXT;
use strict;
use Data::Dumper;

{
  no warnings 'once';
  $URI::XS::ABS_REMOTE_LEADING_DOTS = 1;
}

my $robotstxt;
my $rh = {};
my $ruri = URI::XS->new("http://www.example.com/robots.txt");
my $baseuri = URI::XS->new("http://www.example.com/");

my $line;
while($line = <DATA>) {
    $robotstxt = '';
    $rh = {};
    $robotstxt = $line if ($line !~ /^\#/);
    ParseRobotsTXT::set_agent("scoutjet");
    while ($line = <DATA>) {
        last if ($line =~ /^\#tests/);
        $robotstxt .= $line;
    }

    # Test to see that a missing newline at the end of the file does not break 
    # parsing.    
    $robotstxt =~ s/\n+$//s;

    $rh = ParseRobotsTXT::parse_robots($ruri,\$robotstxt);

    while ($line = <DATA>) {
        last if ($line =~ /^\#robots.txt/);
        my $orgline = $line;
        chomp($line);
        my($agent,$path,$result) = split (/\s+/,$line,3);

        next if (!defined $path or $path eq '');

        $agent  = '*' if ($agent eq '');
        $result = 1 if ($result =~ /^yes/i);
        $result = 0 if ($result =~ /^no/i);

        my $uri = URI::XS->new_abs($path, $baseuri);

        ParseRobotsTXT::set_agent($agent);
        my $allow = ParseRobotsTXT::allowed($rh,$uri);
        unless ( is $allow, $result, "$path for $agent should be $result" ) {
            print "$agent UA rule: " . Dumper(ParseRobotsTXT::agent_rules($rh));
            print Data::Dumper::Dumper($rh);
        }
    }
}

__DATA__
#robots.txt
#tests
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
User-agent: *
Allow: /
Disallow: /foo/
#tests
* /path/ 1
* / 1
* /foo/bar/ 0
* /foo 1
* /index.html 1
* /test.cgi?q=test 1
* /test.cgi?q=test#foo 1
#robots.txt
User-agent: *
Disallow: /uuuuuuu/xx/
Allow: /*/xx/yyy/
#tests
* /path/        1
* /             1
* /uuuuuuu/xx/     0
* /uuuuuuu/xx      1
* /uuuuuuu/xx/zzz/index.html  0
* /uuuuuuu/xx/yyy/index.html  1
#robots.txt
User-agent: *
Disallow: /foo/
Allow: /
#tests
* /path/ 1
* / 1
* /foo/bar/ 0
* /foo 1
* /index.html 1
* /test.cgi?q=test 1
* /test.cgi?q=test#foo 1
#robots.txt
User-agent: *
Disallow: /foo/
Allow: /
#tests
* /path/ 1
* / 1
* /foo/bar/ 0
* /foo 1
* /index.html 1
* /test.cgi?q=test 1
* /test.cgi?q=test#foo 1
#robots.txt
User-agent: *
Disallow: /foo/
Disallow:
#tests
* /path/ 1
* / 1
* /foo/bar/ 0
* /foo 1
* /index.html 1
* /test.cgi?q=test 1
* /test.cgi?q=test#foo 1
#robots.txt
User-agent: *      # comment #1
Disallow: /foo/    # comment 2
Disallow:          # this is a comment by me
#tests
* /path/ 1
* / 1
* /foo/bar/ 0
* /foo 1
* /index.html 1
* /test.cgi?q=test 1
* /test.cgi?q=test#foo 1
#robots.txt
#                    Test wildcarding
User-agent: *
Disallow: /*/feed/
Disallow: /*/trackback/
Disallow: *?
#tests
* /foobar/feed/test.html       0
* /foobar/trackback/test.html  0
* /feed/t2.html                1
* /trackback/t2.html           1
* /fobar.html                  1
* /foo/bar/baz/feed/           0
* /foo/bar/bazfeed/            1
* /test.cgi?q=test             0
* /foo/test.cgi?q=test         0
* /foo/test.cgi?               0
* /foo/test.cgi                1
* /?q=test                     0
