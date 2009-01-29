use Test::MockObject;
use Data::Dumper;

#use Test::More qw(no_plan);
use Test::More tests => 12;
use strict;
use warnings;

BEGIN { 
    use_ok('Finance::Bank::IE::PermanentTSB') 
};

my $DEBUG=0;


my %config;
my $i;
my (@got, @expected);

#---------------------------------------------------------------------------
#  mocked objects
#---------------------------------------------------------------------------

my $agent = Test::MockObject->new();
$agent->fake_new( 'WWW::Mechanize' );
$agent->set_true(qw(quiet env_proxy agent add_header field save_content));
$agent->mock('cookie_jar', sub { return { }; } );

$agent->mock('get', sub { 

        my $res = Test::MockObject->new();
        $res->set_true(qw(is_success));
        return $res; 

    });

$agent->mock('content', sub {
      
        my $ret;

        diag("content() call $i") if $DEBUG;

        # simulating login and balance pages
        if($i == 0) {
            $ret = `cat t/data/loginpage.html`;
        }
        if($i == 1 or $i == 2 or $i == 3) {
            $ret = `cat t/data/loginpage_step2.html`;
        }
        if($i >3) {
            $ret = `cat t/data/balance_homepage.html`;
        }

        # simulating statement pages
        if($i >= 8 and $i <= 9 ) {
            $ret = `cat t/data/statement_page1.html`;
        }
        if($i >= 10 and $i <= 11 ) {
            $ret = `cat t/data/statement_page2.html`;
        }
        if($i >= 11 and $i <= 12 ) {
            $ret = `cat t/data/statement_page3.html`;
        }

        $i++;

        return $ret; 

    });

$agent->mock('submit', sub {

        my $res = Test::MockObject->new();
        $res->set_true(qw(is_success));
        return $res; 

    });

#---------------------------------------------------------------------------
#  end of mocked objects
#---------------------------------------------------------------------------


#---------------------------------------------------------------------------
#  test - login() with testing account
#---------------------------------------------------------------------------

$i=0;
diag("\n\n\n\ntesting login\n\n") if($DEBUG);
%config = ( "open24numba" => 'test', "password" => 'test', "pan" => 'test' );
ok(Finance::Bank::IE::PermanentTSB->login(\%config), "homebanking login");

#---------------------------------------------------------------------------
#  test - login() with undefined configuration as parameter
#---------------------------------------------------------------------------

diag("\n\n\n\ntesting login with missing parameters \n\n") if($DEBUG);
$i=0;
%config = ( "open24numba" => undef, "password" => 'test', "pan" => 'test' );
is(Finance::Bank::IE::PermanentTSB->login(\%config), undef, "missing open24 number");

$i=0;
%config = ( "open24numba" => 'test', "password" => undef, "pan" => 'test');
is(Finance::Bank::IE::PermanentTSB->login(\%config), undef, "missing pass");

$i=0;
%config = ( "open24numba" => 'test', "password" => 'test', "pan" => undef );
is(Finance::Bank::IE::PermanentTSB->login(\%config), undef, "missing pan");

#---------------------------------------------------------------------------
#  test - account balance
#---------------------------------------------------------------------------

# some fake data. NO! THOSE DATA DON'T COME FROM MY HOMEBANKING!
# as well as html files in t/data/ !
@expected = [ 
    {
        'availbal' => '3284.35',
        'accno'    => '0220',
        'accbal'   => '3184.35',
        'accname'  => 'Switch Current A/C',
    },
    {
        'availbal' => '31.34',
        'accno'    => '2667',
        'accbal'   => '-468.66',
        'accname'  => 'Visa Card',
    },
];

$i=0;
diag("\n\n\n\ntesting: check_balance\n\n") if($DEBUG);
%config = ( "open24numba" => 'test', "password" => 'test', "pan" => 'test' );
@got = Finance::Bank::IE::PermanentTSB->check_balance(\%config);
diag(Dumper(@got)) if($DEBUG);
is_deeply( \@got, \@expected);

#---------------------------------------------------------------------------
#  test - account statement - missing parameters
#---------------------------------------------------------------------------

diag("\n\n\n\ntesting: missing parameters in account_statement()\n\n")
if($DEBUG);
is(Finance::Bank::IE::PermanentTSB->account_statement(
    \%config,
    undef, '0220', '2009/01/01','2009/01/31', ALL
), undef, "account_statement: missing account type");

is(Finance::Bank::IE::PermanentTSB->account_statement(
    \%config,
    SWITCH_ACCOUNT, undef, '2009/01/01','2009/01/31', ALL
), undef, "account_statement: missing account number");

is(Finance::Bank::IE::PermanentTSB->account_statement(
    \%config,
    SWITCH_ACCOUNT, '0220', undef,'2009/01/31', ALL
), undef, "account_statement: missing from date");

is(Finance::Bank::IE::PermanentTSB->account_statement(
    \%config,
    SWITCH_ACCOUNT, '0220', '2009/01/01',undef, ALL
), undef, "account_statement: missing from date");

#---------------------------------------------------------------------------
#  test - account statement - switch current account
#---------------------------------------------------------------------------

@expected = [
           {
             'balance' => '+3558.06',
             'date' => '02/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-59.50'
           },
           {
             'balance' => '+3498.06',
             'date' => '03/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-60.00'
           },
           {
             'balance' => '+3372.26',
             'date' => '08/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-125.80'
           },
           {
             'balance' => '+3312.26',
             'date' => '08/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-60.00'
           },
           {
             'balance' => '+3283.56',
             'date' => '09/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-28.70'
           },
           {
             'balance' => '+3237.66',
             'date' => '09/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-45.90'
           },
           {
             'balance' => '+1237.66',
             'date' => '12/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-2000.00'
           },
           {
             'balance' => '+1177.66',
             'date' => '15/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-60.00'
           },
           {
             'balance' => '+1037.66',
             'date' => '15/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-140.00'
           },
           {
             'balance' => '+0977.66',
             'date' => '16/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-60.00'
           },
           {
             'balance' => '+3911.70',
             'date' => '18/12/2008',
             'description' => 'DEPOSIT',
             'euro_amount' => '+2934.04'
           },
           {
             'balance' => '+3901.70',
             'date' => '18/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-10.00'
           },
           {
             'balance' => '+3841.70',
             'date' => '22/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-60.00'
           },
           {
             'balance' => '+3696.00',
             'date' => '22/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-145.70'
           },
           {
             'balance' => '+3651.03',
             'date' => '22/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-44.97'
           },
           {
             'balance' => '+3591.03',
             'date' => '23/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-60.00'
           },
           {
             'balance' => '+3531.04',
             'date' => '23/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-59.99'
           },
           {
             'balance' => '+3509.77',
             'date' => '23/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-21.27'
           },
           {
             'balance' => '+3582.77',
             'date' => '24/12/2008',
             'description' => 'DEPOSIT',
             'euro_amount' => '+73.00'
           },
           {
             'balance' => '+3562.77',
             'date' => '30/12/2008',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-20.00'
           },
           {
             'balance' => '+3169.89',
             'date' => '12/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-42.86'
           },
           {
             'balance' => '+3129.89',
             'date' => '14/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-40.00'
           },
           {
             'balance' => '+3119.89',
             'date' => '15/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-10.00'
           },
           {
             'balance' => '+3079.39',
             'date' => '15/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-40.50'
           },
           {
             'balance' => '+2771.44',
             'date' => '16/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-307.95'
           },
           {
             'balance' => '+2681.62',
             'date' => '19/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-89.82'
           },
           {
             'balance' => '+2600.27',
             'date' => '19/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-81.35'
           },
           {
             'balance' => '+2704.27',
             'date' => '20/01/2009',
             'description' => 'DEPOSIT',
             'euro_amount' => '+104.00'
           },
           {
             'balance' => '+2634.27',
             'date' => '21/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-70.00'
           },
           {
             'balance' => '+2419.76',
             'date' => '23/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-214.51'
           },
           {
             'balance' => '+2429.60',
             'date' => '26/01/2009',
             'description' => 'DEPOSIT',
             'euro_amount' => '+9.84'
           },
           {
             'balance' => '+2419.61',
             'date' => '26/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-9.99'
           },
           {
             'balance' => '+2409.62',
             'date' => '26/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-9.99'
           },
           {
             'balance' => '+2282.28',
             'date' => '26/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-127.34'
           },
           {
             'balance' => '+5196.32',
             'date' => '27/01/2009',
             'description' => 'DEPOSIT',
             'euro_amount' => '+2914.04'
           },
           {
             'balance' => '+5184.35',
             'date' => '27/01/2009',
             'description' => 'WITHDRAWAL',
             'euro_amount' => '-11.97'
           }
         ];


#
$i = 0;
diag("\n\n\n\ntesting: account_statement()\n\n") if($DEBUG);
%config = ( "open24numba" => 'test', "password" => 'test', "pan" => 'test' );
@got = Finance::Bank::IE::PermanentTSB->account_statement(
    \%config,
    SWITCH_ACCOUNT, '0220', '2008/12/01','2009/01/27', ALL);
is_deeply( \@got, \@expected);

#---------------------------------------------------------------------------
#  test - account statement - visa
#---------------------------------------------------------------------------

diag("\n\n\n\ntesting non existent account num in
    account_statement()\n\n") if($DEBUG);
is(Finance::Bank::IE::PermanentTSB->account_statement(
    \%config,
    SWITCH_ACCOUNT, '2667', '2008/12/01','2009/01/27', ALL), undef, 
    "non existent account number");

diag("\n\n\n\ntesting: END\n\n") if($DEBUG);
