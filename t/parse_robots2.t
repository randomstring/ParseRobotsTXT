use strict;
use warnings;
use Test::More tests=>205;
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
    #ParseRobotsTXT::set_agent("scoutjet");
    while ($line = <DATA>) {
        last if ($line =~ /^\#tests/);
        $robotstxt .= $line;
   }

    $rh = ParseRobotsTXT::parse_robots($ruri,\$robotstxt);

    # print Data::Dumper::Dumper($rh);

    while ($line = <DATA>) {
        last if ($line =~ /^\#robots.txt/);
        chomp($line);
        my($agent,$path,$result) = split (/\s+/,$line,3);

        next if (!defined $path or $path eq '');

        $agent  = '*' if ($agent eq '');
        $result = 1 if ($result =~ /^yes/i);
        $result = 0 if ($result =~ /^no/i);

        my $uri = URI::XS->new_abs($path,$baseuri);

        ParseRobotsTXT::set_agent($agent);
        my $allow = ParseRobotsTXT::allowed($rh,$uri);
        my $which = $result ? "ALLOW" : "DISALLOW";

        unless (is $allow, $result, "Agent $agent expected $which for $path") {
            print Dumper(ParseRobotsTXT::agent_rules($rh));
            print Dumper($rh);
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
#                    Test wildcarding
User-agent: *
Disallow: /*/feed/
Disallow: /*/trackback/
Disallow: *?*
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
# test multiple user-agent lines, among other things
User-agent: unhipbot
Disallow: /

User-agent: webcrawler
User-agent: Scoutjet
User-agent: FooBar-bot
User-agent: Bazillator
User-agent: wtf-bot
Disallow:

User-agent: *
Disallow: /org/plans.html
Allow: /org/
Allow: /serv
Allow: /~mak
Disallow: /
#tests
scoutjet htttp://www.fict.org/                      Yes
scoutjet htttp://www.fict.org/index.html            Yes
scoutjet htttp://www.fict.org/robots.txt            Yes
scoutjet htttp://www.fict.org/server.html           Yes
scoutjet htttp://www.fict.org/services/fast.html    Yes
scoutjet htttp://www.fict.org/services/slow.html    Yes
scoutjet htttp://www.fict.org/orgo.gif              Yes
scoutjet htttp://www.fict.org/org/about.html        Yes
scoutjet htttp://www.fict.org/org/plans.html        Yes
scoutjet htttp://www.fict.org/%7Ejim/jim.html       Yes
scoutjet htttp://www.fict.org/%7Emak/mak.html       Yes
Scoutjet htttp://www.fict.org/                      Yes
Scoutjet htttp://www.fict.org/index.html            Yes
Scoutjet htttp://www.fict.org/robots.txt            Yes
Scoutjet htttp://www.fict.org/server.html           Yes
Scoutjet htttp://www.fict.org/services/fast.html    Yes
Scoutjet htttp://www.fict.org/services/slow.html    Yes
Scoutjet htttp://www.fict.org/orgo.gif              Yes
Scoutjet htttp://www.fict.org/org/about.html        Yes
Scoutjet htttp://www.fict.org/org/plans.html        Yes
Scoutjet htttp://www.fict.org/%7Ejim/jim.html       Yes
Scoutjet htttp://www.fict.org/%7Emak/mak.html       Yes
* http://www.fict.org/                            No
* http://www.fict.org/index.html                  No
* http://www.fict.org/robots.txt                  Yes
* http://www.fict.org/server.html                 Yes
* http://www.fict.org/services/fast.html          Yes
* http://www.fict.org/services/slow.html          Yes
* http://www.fict.org/orgo.gif                    No
* http://www.fict.org/org/about.html              Yes
* http://www.fict.org/org/plans.html              No
* http://www.fict.org/%7Ejim/jim.html             No
* http://www.fict.org/%7Emak/mak.html             Yes
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
scoutjet /bar/index.html  no
scoutjet /foo/index.html  no
scoutjet /baz/index.html  no
scoutjet /ok.html         yes
Scoutjet /bar             no
Scoutjet /foo             no
Scoutjet /baz             no
Scoutjet /bar/index.html  no
Scoutjet /foo/index.html  no
Scoutjet /baz/index.html  no
Scoutjet /ok.html         yes
*        /bar             no
*        /foo             yes
*        /baz             yes
*        /bar/index.html  no
*        /foo/index.html  yes
*        /baz/index.html  yes
*        /ok.html         yes
#robots.txt
#       Test Case sensitivity
User-agent: *
Allow: /
Disallow: /foo
Disallow: /Bar
#tests
* /path/        yes
* /             yes
* /Foo          yes
* /Foo/bar      yes
* /foo/bar/         no
* /foo          no
* /F00/bar      yes
* /Bar          no
* /Bar/baz      no
* /BAR/bar/         yes
* /bar/bar      yes
* /bAr/bar      yes
#robots.txt
#       Test regex match not at the head of the path
User-agent: *
Disallow: /search
#tests
* /search/bar/      no
* /search/      no
* /foo/search/bar   yes
* /BAR/bar/search   yes
* /bar/b-search     yes
* /bAr/10/2009/search-foo   yes
#robots.txt
# test multiple user-agent lines, among other things
User-agent: unhipbot
Disallow: /

User-agent: Hooglebot
User-agent: webcrawler
User-agent: ScoutJet
User-agent: FooBar-bot
User-agent: Bazillator
User-agent: wtf-bot
Allow: /cgi-bin/yes.cgi

User-agent: Hooglebot
User-agent: webcrawler
User-agent: scoutjet
User-agent: FooBar-bot
User-agent: Bazillator
User-agent: wtf-bot
Disallow: /cgi-bin

User-agent: *
Disallow: /

#tests
scoutjet  /cgi-bin/no.cgi    no
scoutjet  /cgi-bin/yes.cgi   yes
scoutjet  /index.html        yes
scoutjet  /                  yes
Scoutjet  /cgi-bin/no.cgi    no
Scoutjet  /cgi-bin/yes.cgi   yes
Scoutjet  /index.html        yes
Scoutjet  /                  yes
*         /cgi-bin/no.cgi    no
*         /cgi-bin/yes.cgi   no
*         /index.html        no
*         /                  no
#robots.txt
# http://www.couponcabin.com/robots.txt
User-agent: *
SITEMAP: http://www.couponcabin.com/sitemap.gz
Disallow: /api/
Disallow: /categories/
Disallow: /index/
Disallow: /offers/
Disallow: /r/
Disallow: /search/
Disallow: /stores/
Disallow: /share/
User-agent: MJ12bot
Disallow: /r/
User-agent: MJ12bot
Disallow: /cc-rc/
#tests
scoutjet  /                   yes
scoutjet  /index.html         yes
scoutjet  /r/disallow.html    no
scoutjet  /stores/123.html    no
scoutjet  /offers/x.html      no
scoutjet  /api/search.cgi     no
scoutjet  /share/user.html    no
*         /index.html         yes
*         /                   yes
*         /r/disallow.html    no
*         /stores/123.html    no
*         /offers/x.html      no
*         /api/search.cgi     no
*         /share/user.html    no
#robots.txt
User-agent: *
Disallow: *delete=DELETE*
#tests
scoutjet  /                     yes
scoutjet  /index.html           yes
scoutjet  /cgi-bin/test.cgi     yes
scoutjet  /cgi-bin/delete.cgi                                  yes
scoutjet  /cgi-bin/delete.cgi?delete=DELETE                    no
scoutjet  /cgi-bin/delete.cgi?what=everything&delete=DELETE    no
scoutjet  /cgi-bin/delete.cgi?delete=no                        yes
scoutjet  /cgi-bin/db.cgi?what=everything&delete=DELETE&now=y  no
Scoutjet  /                     yes
Scoutjet  /index.html           yes
Scoutjet  /cgi-bin/test.cgi     yes
Scoutjet  /cgi-bin/delete.cgi                                  yes
Scoutjet  /cgi-bin/delete.cgi?delete=DELETE                    no
Scoutjet  /cgi-bin/delete.cgi?what=everything&delete=DELETE    no
Scoutjet  /cgi-bin/delete.cgi?delete=no                        yes
Scoutjet  /cgi-bin/db.cgi?what=everything&delete=DELETE&now=y  no
*         /                     yes
*         /index.html           yes
*         /cgi-bin/test.cgi     yes
*         /cgi-bin/delete.cgi                                  yes
*         /cgi-bin/delete.cgi?delete=DELETE                    no
*         /cgi-bin/delete.cgi?what=everything&delete=DELETE    no
*         /cgi-bin/delete.cgi?delete=no                        yes
*         /cgi-bin/db.cgi?what=everything&delete=DELETE&now=y  no
#robots.txt
User-agent: *
Disallow: /



User-agent: Scoutjet
crawl-delay: 10
Disallow: /accesslogs
Disallow: /adsystem
Disallow: /apps/
Disallow: /backtocs/
Disallow: /browse/
Disallow: /careerfocus/
Disallow: /cgi/adclick
Disallow: /cgi/alerts
Disallow: /cgi/authordata
Disallow: /cgi/changeuserinfo
Disallow: /cgi/citemap
Disallow: /citemap
Disallow: /cgi/citmgr
Disallow: /citmgr
Disallow: /cgi/cookietest
Disallow: /cgi/crossref-forward-links
Disallow: /cgi/ctalert
Disallow: /cgi/ctmain
Disallow: /cgi/eletter-submit
Disallow: /cgi/etoc
Disallow: /cgi/external_ref
Disallow: /external_ref
Disallow: /cgi/flagsearch
Disallow: /cgi/folders
Disallow: /cgi/login
Disallow: /login
Disallow: /cgi/mailafriend
Disallow: /email
Disallow: /cgi/markedcitation
Disallow: /cgi/myjs
Disallow: /cgi/pdf_extract
Disallow: /cgi/powerpoint
Disallow: /powerpoint
Disallow: /cgi/register
Disallow: /cgi/reprintsidebar
Disallow: /cgi/savedsearch
Disallow: /cgi/scopus
Disallow: /cgi/search
Disallow: /search
Disallow: /cgi/searchhistory
Disallow: /cgi/searchresults
Disallow: /cgi/topics
Disallow: /classifieds/
Disallow: /conf/
Disallow: /guides/
Disallow: /help
Disallow: /honeypot/
Disallow: /math/
Disallow: /misc/press/
Disallow: /press
Disallow: /searchall

User-agent: Fasterfox
Disallow: /
#tests
Scoutjet   /search    no
scoutjet   /search    no
Scoutjet   /ok        yes
scoutjet   /ok        yes


