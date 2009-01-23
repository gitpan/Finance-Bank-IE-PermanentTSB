package Finance::Bank::IE::PermanentTSB;

our $VERSION = '0.02';

use strict;
use warnings;
use Data::Dumper;
use WWW::Mechanize;
use HTML::TokeParser;
use HTML::TableExtract;
use Carp qw(croak carp);
use Date::Calc qw(check_date);

use base 'Exporter';
our @EXPORT = qw(check_balance);
our @EXPORT_OK = qw(mobile_topup);

my %cached_cfg;
my $agent;
my $lastop = 0;

my $BASEURL = "https://www.open24.ie/";


sub login {
    my $self = shift;
    my $config_ref = shift;

    $config_ref ||= \%cached_cfg;

    my $croak = ($config_ref->{croak} || 1);

    for my $reqfield ("open24numba", "password", "pan") {
        if (! defined( $config_ref->{$reqfield})) {
            if ($croak) {
                croak("$reqfield not there!");
            } else {
                carp("$reqfield not there!");
                return;
            }
        }
    }

    if(!defined($agent)) {
        $agent = WWW::Mechanize->new( env_proxy => 1, autocheck => 1,
                                      keep_alive => 10);
        $agent->env_proxy;
        $agent->quiet(0);
        $agent->agent('Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.12) Gecko/20071126 Fedora/1.5.0.12-7.fc6 Firefox/1.5.0.12' );
        my $jar = $agent->cookie_jar();
        $jar->{hide_cookie2} = 1;
        $agent->add_header('Accept' =>
            'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5');
        $agent->add_header('Accept-Language' => 'en-US,en;q=0.5');
        $agent->add_header( 'Accept-Charset' =>
            'ISO-8859-1,utf-8;q=0.7,*;q=0.7' );
        $agent->add_header( 'Accept-Encoding' => 'gzip,deflate' );
    } else {
        # simple check to see if the login is live
        # this based on Waider Finance::Bank::IE::BankOfIreland.pm!
        if ( time - $lastop < 60 ) {
            carp "Last operation 60seconds ago, reusing old session"
                if $config_ref->{debug};
            $lastop = time;
            return 1;
        }
        my $res = $agent->get( $BASEURL . '/online/Account.aspx' );
        if ( $res->is_success ) {
            if($agent->content =~ /ACCOUNT SUMMARY/is) {
                $lastop = time;
                carp "Short-circuit: session still valid"
                    if $config_ref->{debug};
                return 1;
            }
        }
        carp "Session has timed out, redoing login"
            if $config_ref->{debug};
    }

    # retrieve the login page
    my $res = $agent->get($BASEURL . '/online/login.aspx');
    $agent->save_content('/var/tmp/loginpage.html') if $config_ref->{debug};

    # something wrong?
    if(!$res->is_success) {
        croak("Unable to get login page!");
    }

    # page not found?
    if($agent->content =~ /Page Not Found/is) {
        croak("HTTP ERROR 404: Page Not Found");
    }

    # Login - Step 1 of 2
    $agent->field('txtLogin', $config_ref->{open24numba});
    $agent->field('txtPassword', $config_ref->{password});
    # PermanentTSB website sucks...
    # there's no normal submit button, the "continue" button is a
    # <a href="javascript:__doPostBack('lbtnContinue','')"> link
    # that launches a Javascript function. This function sets
    # the __EVENTTARGET to 'lbtnContinue'. Here we are simulating this
    # bypassing the Javascript code :)
    $agent->field('__EVENTTARGET', 'lbtnContinue');
    $res = $agent->submit();
    # something wrong?
    if(!$res->is_success) {
        croak("Unable to get login page!");
    }
    $agent->save_content("/var/tmp/step1_result.html") if $config_ref->{debug};

    # Login - Step 2 of 2
    if(!$agent->content =~ /LOGIN STEP 2 OF 2/is) {
        #TODO: check che content of the page and deal with it
    } else {
        set_pan_fields($agent, $config_ref);
        $res = $agent->submit();
        $agent->save_content("/var/tmp/step2_pan_result.html") 
            if $config_ref->{debug};
    }

    return 1;
   
}

sub set_pan_fields {

    my $agent = shift;
    my $config_ref = shift;

    my $p = HTML::TokeParser->new(\$agent->response()->content());
    # convert the pan string into an array
    my @pan_digits = ();
    my @pan_arr = split('',$config_ref->{pan});
    # look for <span> with ids "lblDigit1", "lblDigit2" and "lblDigit3"
    # and build an array
    # the PAN, Personal Access Number is formed by 6 digits.
    while (my $tok = $p->get_tag("span")){
        if(defined $tok->[1]{id}) {
            if($tok->[1]{id} =~ m/lblDigit[123]/) {
                my $text = $p->get_trimmed_text("/span");
                # normally the webpage shows Digit No. x
                # where x is the position of the digit inside 
                # the PAN number assigne by the bank to the owner of the
                # account
                # here we are building the @pan_digits array
                push @pan_digits, $pan_arr[substr($text,10)-1];
            }
        }
    }
    $agent->field('txtDigitA', $pan_digits[0]);
    $agent->field('txtDigitB', $pan_digits[1]);
    $agent->field('txtDigitC', $pan_digits[2]);
    $agent->field('__EVENTTARGET', 'btnContinue');
}

sub check_balance {

    my $self = shift;
    my $config_ref = shift;
    my $res;

    $config_ref ||= \%cached_cfg;
    my $croak = ($config_ref->{croak} || 1);
 
    $self->login($config_ref) or return;

    $res = $agent->get($BASEURL . '/online/Account.aspx');
    my $p = HTML::TokeParser->new(\$agent->response()->content());
    my $i = 0;
    my @array;
    my $hash_ref = {};
    while (my $tok = $p->get_tag("td")){
        if(defined $tok->[1]{style}) {
            if($tok->[1]{style} eq 'width:25%;') {
                my $text = $p->get_trimmed_text("/td");
                if($i == 0) {
                    $hash_ref = {};
                    $hash_ref->{'accname'} = $text;
                } 
                if($i == 1) {
                    $hash_ref->{'accno'} = $text;
                }
                if($i == 2) {
                    $hash_ref->{'accbal'} = $text;
                }
                if($i == 3) {
                    $hash_ref->{'availbal'} = $text;
                }
                $i++;
                if($i == 4) {
                    $i = 0;
                    push @array, $hash_ref;
                }
            }
        }
    }

    return @array;

}

# TODO
sub account_statement {
    # TODO: 
    # - get the argument
    # - verify if $account exists
    # - verify if $from and $to are valid
    # - go to /online/Statement.aspx
    # - select account select box
    # - press submit button called "show/order statement"
    # - select "from date" and "to date"
    # - select transation type "all" (maybe deposit/withdrawals?)
    # - press the "show statement button"
    # - deal with invalid date range (like range old than 6 months)
    # - parse output page clicking "next" button until the button
    #   "another statement" is present. all the data must be
    #   inserted into an array
    # - return the array to the caller
    #   array should contain [date, description, euro amount, balance]
    
    my ($self, $config_ref, $account, $from, $to) = @_;
    my ($res, @ret_array);

    $config_ref ||= \%cached_cfg;
    my $croak = ($config_ref->{croak} || 1);

    if(defined $from and defined $to) {
        # check date_from, date_to
        foreach my $date ($from, $to) {
            # date should be in format yyyy/mm/dd
            if(not $date  =~ m/^\d{4}\/\d{2}\/\d{2}$/) {
                carp("Date $date should be in format 'yyyy/mm/dd'");
            }
            # date should be valid, this is using Date::Calc->check_date()
            my @d = split "/", $date;
            if (not check_date($d[0],$d[1],$d[2])) {
                carp("Date $date is not valid!");
            }
        }
    }

    if(defined $account) {
        if(not $account =~ m/.+ - \d{4}$/) {
            carp("Account $account should be in format 'account_name - integer'");
        }
    }

    # TODO: call check_balance and fetch the list of accounts
    # TODO: check the account provided to verify if it exists
    #       within the array retrieved 

    $self->login($config_ref) or return;

    # go to the Statement page
    $res = $agent->get($BASEURL . '/online/Statement.aspx');

    return @ret_array;

}

#TODO
sub funds_transfer {

}

#TODO
sub mobile_topup {

}

sub logoff {
    my $self = shift;
    my $config_ref = shift;

    my $res = $agent->get($BASEURL . '/online/DoLogOff.aspx');
    $agent->save_content("/var/tmp/logoff.html") if $config_ref->{debug};
}

1;

__END__
=head1 NAME

Finance::Bank::IE::PermanentTSB - Perl Interface to the PermanentTSB
Open24 homebanking

=head1 SYNOPSIS

use Finance::Bank::IE::PermanentTSB;

my %config = (
    "open24numba" => "1060xxxxx",
    "password" => "your_internet_password",
    "pan" => "123456",
    "debug" => 1,
    );

my @balance = Finance::Bank::IE::PermanentTSB->check_balance(\%config);
Finance::Bank::IE::PermanentTSB->logoff(\%config);

@balance is an array of hash like this:

$VAR1 = {
    'availbal' => 'EUR',
    'accno' => 'EUR',
    'accbal' => 'EUR',
    'accname' => 'Switch Current A/C'
};
$VAR2 = {
    'availbal' => 'EUR',
    'accno' => 'EUR',
    'accbal' => 'EUR',
    'accname' => 'Switch Current A/C'
};


=head1 DESCRIPTION

This is a Perl interface to the PermanenteTSB Open24 homebanking.

Features:

=over

=item * account(s) balance

=item * account(s) statement (to be implemented)

=item * mobile phone top up (to be implemented)

=item * funds transfer (to be implemented)

=back

=head1 SEE ALSO

N/A

=head1 AUTHOR

Angelo "pallotron" Failla, E<lt>pallotron@freaknet.orgE<gt>
http://www.pallotron.net
http://www.vitadiunsysadmin.net

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Angelo "pallotron" Failla

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
