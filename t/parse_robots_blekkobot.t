use strict;
use warnings;

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
    
    $rh = ParseRobotsTXT::parse_robots($ruri,\$robotstxt);

#    print Data::Dumper::Dumper($rh);

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
#robots.txt
User-agent: *
Disallow: /tmp
Disallow: /bar/
Disallow: /a%3cd.html
Disallow: /b%3Cd.html
Disallow: /c%3CD.html
Disallow: /a%2fb.html
Disallow: /d/b.html
Disallow: /%7ejoe/index.html
Disallow: /~bob/index.html
#tests
* /tmp 0
* /tmp.html 0
* /tmp/a.html 0
* /bar 1
* /bar/ 0
* /bar/a.html 0
* /a%3cd.html 0
* /a%3Cd.html 0
* /b%3cd.html 0
* /b%3Cd.html 0
* /a%2fb.html 0
* /a/b.html 1
* /d/b.html 0
* /d%2fb.html 1
* /~joe/index.html 0
* /%7Ejoe/index.html 0
* /~bob/index.html 0
* /%7Ebob/index.html 0
#robots.txt
User-agent: unhipbot
Disallow: /

User-agent: webcrawler
User-agent: excite
Disallow:

User-agent: *
Disallow: /org/plans.html
Allow: /org/
Allow: /serv
Allow: /~mak
Disallow: /
#tests
unhipbot http://www.fict.org/                         No
unhipbot http://www.fict.org/index.html               No
unhipbot http://www.fict.org/robots.txt               Yes
unhipbot http://www.fict.org/server.html              No
unhipbot http://www.fict.org/services/fast.html       No
unhipbot http://www.fict.org/services/slow.html       No
unhipbot http://www.fict.org/orgo.gif                 No
unhipbot http://www.fict.org/org/about.html           No
unhipbot http://www.fict.org/org/plans.html           No
unhipbot http://www.fict.org/%7Ejim/jim.html          No
unhipbot http://www.fict.org/%7Emak/mak.html          No
webcrawler htttp://www.fict.org/                      Yes
webcrawler htttp://www.fict.org/index.html            Yes
webcrawler htttp://www.fict.org/robots.txt            Yes
webcrawler htttp://www.fict.org/server.html           Yes
webcrawler htttp://www.fict.org/services/fast.html    Yes
webcrawler htttp://www.fict.org/services/slow.html    Yes
webcrawler htttp://www.fict.org/orgo.gif              Yes
webcrawler htttp://www.fict.org/org/about.html        Yes
webcrawler htttp://www.fict.org/org/plans.html        Yes
webcrawler htttp://www.fict.org/%7Ejim/jim.html       Yes
webcrawler htttp://www.fict.org/%7Emak/mak.html       Yes
excite htttp://www.fict.org/                          Yes
excite htttp://www.fict.org/index.html                Yes
excite htttp://www.fict.org/robots.txt                Yes
excite htttp://www.fict.org/server.html               Yes
excite htttp://www.fict.org/services/fast.html        Yes
excite htttp://www.fict.org/services/slow.html        Yes
excite htttp://www.fict.org/orgo.gif                  Yes
excite htttp://www.fict.org/org/about.html            Yes
excite htttp://www.fict.org/org/plans.html            Yes
excite htttp://www.fict.org/%7Ejim/jim.html           Yes
excite htttp://www.fict.org/%7Emak/mak.html           Yes
other http://www.fict.org/                            No
other http://www.fict.org/index.html                  No
other http://www.fict.org/robots.txt                  Yes
other http://www.fict.org/server.html                 Yes
other http://www.fict.org/services/fast.html          Yes
other http://www.fict.org/services/slow.html          Yes
other http://www.fict.org/orgo.gif                    No
other http://www.fict.org/org/about.html              Yes
other http://www.fict.org/org/plans.html              No
other http://www.fict.org/%7Ejim/jim.html             No
other http://www.fict.org/%7Emak/mak.html             Yes
#robots.txt
User-agent: *
Disallow: /?
#tests
* /        1
* /?       0
* /?q=test 0
* /foo     1
* /foo/    1
* /foo?    1
* /foo?q=1 1
#robots.txt
User-agent: *
Disallow: .pdf$
Disallow: .mp3$
Disallow: .mov$
#tests
* /test.pdf            0
* /test.pdf?q=1        1
* /paris.mov           0
* /paris.mov/dir.html  1
* /mov                 1
* /.mov                0
* /a.mov               0
* /.mov/i.html         1
#robots.txt
# ignore rules for someone else's domain
User-agent: *
Disallow: http://www.google.com/index.html
#tests
* /index.html          1
* /test.pdf?q=1        1
#robots.txt
User-agent: scoutjet
Disallow: /foo

User-agent: *
Disallow: /bar

User-agent: Ascoutjet
Allow: /bar

User-agent: scout
Allow: /foo

User-agent: scoutjets
Allow: /baz

User-agent: Mozilla/5.0 (compatible; ScoutJet; +http://www.scoutjet.com/)
Disallow: /bar
Disallow: /baz
#tests
scoutjet /bar             no
scoutjet /foo             no
scoutjet /baz             no
Scoutjet /baz             no
ScoutJET /baz             no
scoutjet /bar/index.html  no
scoutjet /foo/index.html  no
scoutjet /baz/index.html  no
scoutjet /ok.html         yes
blekkobot /bar             no
blekkobot /foo             no
blekkobot /baz             no
BlekkoBOT /baz             no
Blekkobot /baz             no
blekkobot /bar/index.html  no
blekkobot /foo/index.html  no
blekkobot /baz/index.html  no
blekkobot /ok.html         yes
*        /bar             no
*        /foo             yes
*        /baz             yes
*        /bar/index.html  no
*        /foo/index.html  yes
*        /baz/index.html  yes
*        /ok.html         yes
#robots.txt
#http://www.mildewhall.com/robots.txt
User-agent: BuzzTracker 
Disallow: /cgi-bin
Crawl-Delay: 120 
#
User-agent: Twiceler
Disallow: /
Disallow: /cgi-bin
Crawl-Delay: 1200 
#
User-agent: Slurp
Disallow: /cgi-bin
Crawl-delay: 2
#
User-agent: *
Disallow: /cgi-bin
Disallow: /stuff/MHStock
Disallow: /BlogPix
Disallow: /phpMyAdmin-2.6.4-pl4
Disallow: /galleries
Disallow: /images
Disallow: /TESOL
Disallow: /weba
#tests
* http://www.mildewhall.com/cgi-bin/emaildabbler.cgi/isopsephism no
Twiceler http://www.mildewhall.com/cgi-bin/emaildabbler.cgi/isopsephism no
scoutjet http://www.mildewhall.com/cgi-bin/emaildabbler.cgi/isopsephism no
blekkobot http://www.mildewhall.com/cgi-bin/emaildabbler.cgi/isopsephism no

#robots.txt
#http://twitter.com/robots.txt
# Every bot that might possibly read and respect this file.
User-agent: *
Disallow: /*?
Disallow: /*/with_friends
#tests
* http://twitter.com/favicon.ico    yes
* http://twitter.com/favicon.ico?   no
#robots.txt
# broken duckduckgo.com robots.txt tests
User-agent: ia_archiver
Disallow: /
Disallow: /*?
#tests
googlebot    /?q=foo     yes
scoutjet     /ok.html    yes
scoutjet     /?q=foo     yes
blekkobot    /ok.html    yes
blekkobot    /?q=foo     yes
ia_archiver  /?q=foo     no
#robots.txt
User-agent: *
Disallow: /*?
#tests
googlebot    /?q=foo     no
scoutjet     /ok.html    yes
scoutjet     /?q=foo     no
blekkobot    /ok.html    yes
blekkobot    /?q=foo     no
ia_archiver  /?q=foo     no
#robots.txt
User-Agent: *
Disallow:  *action=buy_now*
#tests
*  /foo/path/part?action=buy_now  0
*  /?action=buy_now    0
*  /foo/path/part?action=buy_now&suckage=1  0
*  /foo/path/part?action=buy_no        1
*  /foo/path/part?action=buy_no&foo=1  1
#robots.txt http://www.clemson.edu/robots.txt
User-agent: *
Disallow: /

User-agent: Googlebot
Allow: /

User-agent: Googlebot-Mobile
Allow: /

User-agent: Googlebot-Image
Allow: /

User-agent: Mediapartners-Google
Allow: /

User-agent: Adsbot-Google
Allow: /

User-agent: msnbot
Allow: /

User-agent: psbot
Allow: /

User-agent: yahoo-slurp
Allow: /

User-agent: yahoo-mmcrawler
Allow: /

User-agent: teoma
Allow: /

User-agent: robozilla
Allow: /

User-agent: ia_archiver
Allow: /

User-agent: baiduspider
Allow: /

User-agent: Browsershots
Allow: /

User-agent: W3C-checklink
Allow: /
#tests
googlebot    /clemson.html    yes
ia_archiver  /clemson.html    yes
msnbot       /clemson.html    yes
scoutjet     /clemson.html    no
blekkobot    /clemson.html    no
googlebot    /                yes
ia_archiver  /                yes
msnbot       /                yes
blekkobot    /                no
scoutjet     /                no
#robots.txt http://videoeta.com/robots.txt
User-Agent: *
Crawl-delay: 10
User-agent: MSNbot
Crawl-delay: 10
User-agent: Teoma
Crawl-delay: 10
User-Agent: OmniExplorer_Bot
Disallow: /
User-agent: BecomeBot
Disallow: /
User-agent: psbot
Disallow: /
User-Agent: MJ12bot
Disallow: /
User-agent: Nutch
Disallow: /
User-agent: ConveraMultiMediaCrawler
Disallow: /
User-agent: Gigabot
Disallow: /
User-agent: TurnitinBot
Disallow: / 
User-agent: DiamondBot
Disallow: / 
User-agent: ichiro
Disallow: / 
User-agent: VoilaBot
Disallow: / 
User-agent: Exabot
Disallow: / 
User-agent: ConveraCrawler
Disallow: / 
User-agent: Speedy
Disallow: / 
User-agent: IlseBot
Disallow: / 
User-agent: FindLinks
Disallow: /
User-agent: Twiceler
Disallow: /
#tests
googlebot          /veta.html    yes
ia_archiver        /veta.html    yes
msnbot             /veta.html    yes
scoutjet           /veta.html    yes
blekkobot          /veta.html    yes
googlebot          /             yes
ia_archiver        /             yes
msnbot             /             yes
scoutjet           /             yes
blekkobot          /             yes
twiceler           /veta.html    no
twiceler           /             no
nutch              /veta.html    no
nutch              /             no
OmniExplorer_Bot   /veta.html    no
OmniExplorer_Bot   /             no
#robots.txt
# test the affect of comments in the middle of a rule section
User-agent: *
Allow: /foo/
# a comment
Disallow: /


User-agent: scoutjet
# some comment line
User-agent: googlebot
Disallow: /

#tests
scoutjet   /index.html               no
scoutjet   /foo/index.html           no
blekkobot   /index.html               no
blekkobot   /foo/index.html           no
googlebot  /index.html               no
googlebot  /foo/index.html           no
msnbot     /index.html               no
msnbot     /foo/index.html           yes
#robots.txt
# customs.gov/robots.txt
User-agent: gsa-crawler
Allow: /

User-agent: googlebot
Allow: /
Request-rate: 1/5
Visit-time: 0400-1100

User-agent: slurp
Allow: /
Request-rate: 1/5
Visit-time: 0400-1100

User-agent: msnbot
Allow: /
Request-rate: 1/5
Visit-time: 0400-1100

User-agent: bingbot
Allow: /
Request-rate: 1/5
Visit-time: 0400-1100
User-agent: *

Disallow: /

#tests
scoutjet   /index.html               no
scoutjet   /foo/index.html           no
blekkobot  /index.html               no
blekkobot  /foo/index.html           no
googlebot  /index.html               yes
googlebot  /foo/index.html           yes
msnbot     /index.html               yes
msnbot     /foo/index.html           yes
bingbot    /index.html               yes
bingbot    /foo/index.html           yes
