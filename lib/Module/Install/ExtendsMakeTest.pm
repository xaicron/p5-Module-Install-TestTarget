package Module::Install::ExtendsMakeTest;
use 5.006_002;
use strict;
#use warnings; # XXX: warnings.pm produces a lot of 'redefine' warnings!
our $VERSION = '0.04';

sub _deprecated {
    print STDERR <<EOM;
***** WARNING *****

Module::Install::ExtendsMakeTest has been DEPRECATED.
Please use Module::Install::TestTarget instead.

EOM
}

use base qw(Module::Install::Base);
use Config;
use Carp qw(croak);

our($TEST_TARGET, $ORIG_TEST_VIA_HARNESS);

our $TEST_DYNAMIC = {
    env                => '',
    includes           => '',
    modules            => '',
    before_run_codes   => '',
    after_run_codes    => '',
    before_run_scripts => '',
    after_run_scripts  => '',
};

# override the default `make test`
sub replace_default_make_test {
    _deprecated;

    my ($self, %args) = @_;
    my %test = _build_command_parts(%args);
    $TEST_DYNAMIC = \%test;
}

# create a new test target
sub extends_make_test {
    _deprecated;

    my ($self, %args) = @_;
    my $target = $args{target} || croak 'target must be spesiced at extends_make_test()';
    my $alias  = $args{alias}  || '';

    my $test = _assemble(_build_command_parts(%args));

    $alias = $alias ? qq{\n$alias :: $target\n\n} : qq{\n};
    $self->postamble(
          $alias
        . qq{$target :: pure_all\n}
        . qq{\t} . $test
    );
}

sub _build_command_parts {
    my %args = @_;

    #XXX: _build_command_parts() will be called first, so we put ithere
    unless(defined $ORIG_TEST_VIA_HARNESS) {
        $ORIG_TEST_VIA_HARNESS = MY->can('test_via_harness');
        no warnings 'redefine';
        *MY::test_via_harness = \&_test_via_harness;
    }

    for my $key (qw/includes modules before_run_scripts after_run_scripts before_run_codes after_run_codes tests/) {
        $args{$key} ||= [];
        $args{$key} = [$args{$key}] unless ref $args{$key} eq 'ARRAY';
    }
    $args{env} ||= {};

    my %test;
    $test{includes} = @{$args{includes}} ? join '', map { qq|"-I$_" | } @{$args{includes}} : '';
    $test{modules}  = @{$args{modules}}  ? join '', map { qq|"-M$_" | } @{$args{modules}}  : '';
    $test{tests}    = @{$args{tests}}    ? join '', map { qq|"$_" |   } @{$args{tests}}    : '$(TEST_FILES)';
    for my $key (qw/before_run_scripts after_run_scripts/) {
        $test{$key} = @{$args{$key}} ? join '', map { qq|do '$_'; | } @{$args{$key}} : '';
    }
    for my $key (qw/before_run_codes after_run_codes/) {
        my $codes = join '', map { _build_funcall($_) } @{$args{$key}};
        $test{$key} = _quote($codes);
    }
    $test{env} = %{$args{env}} ? _quote(join '', map {
        my $key = _env_quote($_);
        my $val = _env_quote($args{env}->{$_});
        sprintf "\$ENV{q{%s}} = q{%s}; ", $key, $val
    } keys %{$args{env}}) : '';

    return %test;
}

my $bd;
sub _build_funcall {
    my($code) = @_;
    if(ref $code eq 'CODE') {
        $bd ||= do { require B::Deparse; B::Deparse->new() };
        $code = $bd->coderef2text($code);
    }
    return qq|sub { $code }->(); |;
}

sub _quote {
    my $code = shift;
    $code =~ s/\$/\\\$\$/g;
    $code =~ s/"/\\"/g;
    $code =~ s/\n/ /g;
    if ($^O eq 'MSWin32' and $Config{make} eq 'dmake') {
        $code =~ s/\\\$\$/\$\$/g;
        $code =~ s/{/{{/g;
        $code =~ s/}/}}/g;
    }
    return $code;
}

sub _env_quote {
    my $val = shift;
    $val =~ s/}/\\}/g;
    return $val;
}

sub _assemble {
    my %args = @_;
    my $command = MY->$ORIG_TEST_VIA_HARNESS($args{perl} || '$(FULLPERLRUN)', $args{tests});

    # inject includes and modules before the first switch
    $command =~ s/("- \S+? ")/$args{includes}$args{modules}$1/xms;

    # inject snipetts in the one-liner
    $command =~ s{("-e" \s+ ") (.+) (")}{
        join '', $1,
            $args{env},
            $args{before_run_scripts},
            $args{before_run_codes},
            $2,
            $args{after_run_scripts},
            $args{after_run_codes},
            $3,
    }xmse;
    return $command;
}

sub _test_via_harness {
    my($self, $perl, $tests) = @_;

    $TEST_DYNAMIC->{perl} = $perl;
    $TEST_DYNAMIC->{tests} ||= $tests;
    return _assemble(%$TEST_DYNAMIC);
}

1;
__END__

=head1 NAME

Module::Install::ExtendsMakeTest - Assembles test targets for `make` with code snippets

=head1 SYNOPSIS

inside Makefile.PL:

  use inc::Module::Install;
  tests 't/*t';
  
  # create a new test target
  extends_make_test(
      includes           => ["$ENV{HOME}/perl5/lib"],
      modules            => [qw/Foo Bar/],
      before_run_scripts => [qw/before.pl/],
      after_run_scripts  => [qw/after.pl/],
      before_run_codes   => ['print "start -> ", scalar localtime, "\n"'],
      after_run_codes    => ['print "end   -> ", scalar localtime, "\n"'],
      tests              => ['t/baz/*t'],
      env                => { PERL_ONLY => 1 },
      target             => 'foo',     # create make foo target
      alias              => 'testall', # make testall is run the make foo
  );

maybe make foo is:

  perl "-MExtUtils::Command::MM" "-I/home/xaicron/perl5/lib" "-MFoo" "-MBar" "-e" "do 'before.pl'; sub { print \"start -> \", scalar localtime, \"\n\" }->(); test_harness(0, 'inc'); do 'after.pl'; sub { print \"end -> \", scalar localtime, \"\n\" }->();" t/baz/*t

=head1 DESCRIPTION

This module has been B<DEPRECATED>. Please use Module::Install::TestTarget instead.

Module::Install::ExtendsMakeTest creates C<make test> variations with code snippets.
This helps module developers to test their distributions with various conditions, e.g.
under C<< PERL_ONLY=1 >> or the control of some testing modules.

=head1 FUNCTIONS

=head2 extends_make_test(%args)

Defines a new test target with I<%args>.

I<%args> are:

=over

=item C<< includes => \@include_paths >>

Sets include paths.

  extends_make_test(
      includes => ['/path/to/inc'],
  );

  # `make test` will be something like this:
  perl -I/path/to/inc  -MExtUtils::Command::MM -e "test_harness(0, 'inc')" t/*t

=item C<< modules => \@module_names >>

Sets modules which are loaded before running C<test_harness()>.

  extends_make_test(
      modules => ['Foo', 'Bar::Baz'],
  );
  
  # `make test` will be something like this:
  perl -MFoo -MBar::Baz -MExtUtils::Command::MM -e "test_harness(0, 'inc')" t/*t

=item C<< before_run_scripts => \@scripts >>

Sets scripts to run before running C<test_harness()>.

  extends_make_test(
      before_run_scripts => ['tool/before_run_script.pl'],
  );
  
  # `make test` will be something like this:
  perl -MExtUtils::Command::MM -e "do 'tool/before_run_script.pl; test_harness(0, 'inc')" t/*t

=item C<< after_run_script => \@scripts >>

Sets scripts to run after running C<test_harness()>.

  use inc::Module::Install;
  tests 't/*t';
  extends_make_test(
      after_run_script => ['tool/after_run_script.pl'],
  );
  
  # `make test` will be something like this:
  perl -MExtUtils::Command::MM -e "test_harness(0, 'inc'); do 'tool/before_run_script.pl;" t/*t

=item C<< before_run_codes => \@codes >>

Sets perl codes to run before running C<test_harness()>.

  use inc::Module::Install;
  tests 't/*t';
  extends_make_test(
      before_run_codes => ['print scalar localtime , "\n"', sub { system qw/cat README/ }],
  );
  
  # `make test` will be something like this:
  perl -MExtUtils::Command::MM "sub { print scalar localtme, "\n" }->(); sub { system 'cat', 'README' }->(); test_harness(0, 'inc')" t/*t

The perl codes runs before_run_scripts runs later.

=item C<< after_run_codes => \@codes >>

Sets perl codes to run after running C<test_harness()>.

  use inc::Module::Install;
  tests 't/*t';
  extends_make_test(
      after_run_codes => ['print scalar localtime , "\n"', sub { system qw/cat README/ }],
  );
  
  # `make test` will be something like this:
  perl -MExtUtils::Command::MM "test_harness(0, 'inc'); sub { print scalar localtme, "\n" }->(); sub { system 'cat', 'README' }->();" t/*t

The perl codes runs after_run_scripts runs later.

=item C<< target => $name >>

Sets a new make target of the test.

  use inc::Module::Install;
  tests 't/*t';
  extends_make_test(
      before_run_scripts => 'tool/force-pp.pl',
      target             => 'test_pp',
  );
  
  # `make test_pp` will be something like this:
  perl -MExtUtils::Command::MM -e "do 'tool/force-pp.pl'; test_harness(0, 'inc')" t/*t

=item C<< alias => $name >>

Sets an alias of the test.

  extends_make_test(
      before_run_scripts => 'tool/force-pp.pl',
      target             => 'test_pp',
      alias              => 'testall',
  );
  
  # `make test_pp` and `make testall` will be something like this:
  perl -MExtUtils::Command::MM -e "do 'tool/force-pp.pl'; test_harness(0, 'inc')" t/*t

=item C<< env => \%env >>

Sets environment variables.

  extends_make_test(
      env => {
          FOO => 'bar',
      },
  );
  
  # `make test` will be something like this:
  perl -MExtUtils::Command::MM -e "\$ENV{q{FOO}} = q{bar}; test_harness(0, 'inc')" t/*t

=item C<< tests => \@test_files >>

Sets test files to run.

  extends_make_test(
      tests  => ['t/foo.t', 't/bar.t'],
      env    => { USE_FOO => 1 },
      target => 'test_foo',
  );

  # `make test_foo` will be something like this:
  perl -MExtUtils::Command::MM -e "$ENV{USE_FOO} = 1 test_harness(0, 'inc')" t/foo.t t/bar.t

=back

=head2 replace_default_make_test(%args)

Override the default `make test` with I<%args>.

Same argument as C<extends_make_test()>, but `target` and `alias` are not allowed.

=head1 AUTHOR

Yuji Shimada E<lt>xaicron {at} cpan.orgE<gt>

Goro Fuji (gfx) <gfuji at cpan.org>

=head1 SEE ALSO

L<Module::Install>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
