use Test::More;
use Test::WWW::Mechanize;
use YAML::Syck qw'LoadFile';
use Data::Dumper;
use Modern::Perl;

use C4::Context;
use C4::Circulation;
use C4::Members;

# Check that KOHA_TEST_CONFIG is set and give a verbose warning if it is not
# FIXME Move this to a module? 
BAIL_OUT("You must set the environment variable KOHA_TEST_CONFIG to ".
         "the path of a YAML file that contains relevant information ".
         "for running these tests. See the wiki or something for what ".
         "info to include in the file.") unless $ENV{'KOHA_TEST_CONFIG'};

# Read the config file
my ( $config ) = LoadFile( $ENV{'KOHA_TEST_CONFIG'} );

# Check that the patron exits
my ( $patron ) = GetMemberDetails( $config->{'patron'}->{'borrowernumber'} );
is ( $patron->{'borrowernumber'}, $config->{'patron'}->{'borrowernumber'}, 'Patron has borrowernumber ' . $config->{'patron'}->{'borrowernumber'} );

# Check that the librarian exits
my ( $librarian ) = GetMemberDetails( $config->{'librarian'}->{'borrowernumber'} );
is ( $librarian->{'borrowernumber'}, $config->{'librarian'}->{'borrowernumber'}, 'Librarian has borrowernumber ' . $config->{'librarian'}->{'borrowernumber'} );

# Set up the userenv for the librarian, in case we want to do things like issue loans directly, 
# by talking to the Koha API, and not by using T:W:M to simulate the librarian.
C4::Context->_new_userenv('dummy');
C4::Context::set_userenv( $config->{'librarian'}->{'borrowernumber'}, undef, undef, undef, undef, $config->{'librarian'}->{'branchcode'}, undef, undef, undef, undef);
is( C4::Context->userenv->{'branch'}, $config->{'librarian'}->{'branchcode'}, 'Branch for the librarian is ' . $config->{'librarian'}->{'branchcode'} );

## Make sure the initial setup is OK

# OPACPrivacy
C4::Context->set_preference( 'OPACPrivacy', 0 );
my $OPACPrivacy = C4::Context->preference('OPACPrivacy');
is( $OPACPrivacy, 0, 'OPACPrivacy is off' );

# opacreadinghistory
C4::Context->set_preference( 'opacreadinghistory', 1 );
my $opacreadinghistory = C4::Context->preference('opacreadinghistory');
is( $opacreadinghistory, 1, 'opacreadinghistory is on' );

# AnonymousPatron
C4::Context->set_preference( 'AnonymousPatron', 0 );
my $AnonymousPatron = C4::Context->preference('AnonymousPatron');
is( $AnonymousPatron, 0, "AnonymousPatron is $AnonymousPatron" );

## Set up user agents and some frequently used variables

my $ua_lib = Test::WWW::Mechanize->new( autocheck => 1 );
my $ua_pat = Test::WWW::Mechanize->new( autocheck => 1 );

my $opac     = $config->{'opac'}->{'url'};
my $intranet = $config->{'intranet'}->{'url'};

## Log in librarian

$ua_lib->get_ok( "$intranet/cgi-bin/koha/mainpage.pl", "connect to intranet at $intranet" );
$ua_lib->form_id('loginform');
$ua_lib->field( 'password', $config->{'librarian'}->{'password'} );
$ua_lib->field( 'userid', $config->{'librarian'}->{'username'} );
$ua_lib->field( 'branch', '' );
$ua_lib->click_ok( undef, 'submit login form' );

## Look up patron

# $ua_lib->get_ok( "$intranet/cgi-bin/koha/circ/circulation-home.pl", 'load circ page' );
# $ua_lib->form_id('patronsearch');
# $ua_lib->field( 'findborrower', $config->{'patron'}->{'cardnumber'} );
# $ua_lib->click_ok( undef, 'submit search form' );
# $ua_lib->content_contains( $config->{'patron'}->{'cardnumber'} );
# $ua_lib->content_contains( $config->{'patron'}->{'firstname'} );

## Lend some books
# Don't bother with mecahnizing this, it's the check in screen we are really interested in

AddIssue( $patron, 1 );
# AddIssue( $patron, 2 );
# AddIssue( $patron, 3 );

## Return the book

$ua_lib->get_ok( "$intranet/cgi-bin/koha/circ/circulation-home.pl", 'load circ page' );
$ua_lib->form_number( 2 ); # FIXME Make a patch for adding id/name to this form
$ua_lib->field( 'barcode', 1 );
$ua_lib->click_ok( undef, 'return loan' );
$ua_lib->content_contains( 'Record 1', 'page contains title of record' );

## Look at the circulation history tab of the patron
$ua_lib->get_ok( "$intranet/cgi-bin/koha/members/readingrec.pl?borrowernumber=" . $config->{'patron'}->{'borrowernumber'}, 'load circulation history page' );
$ua_lib->content_contains( 'Record 1', 'page contains title of record' );

done_testing();

__END__

## Return the books

AddReturn( 1, 'CPL' );
AddReturn( 2, 'CPL' );
AddReturn( 3, 'CPL' );
