package Test::CheckDeps;
use strict;
use warnings FATAL => 'all';

use Exporter 5.57 'import';
our @EXPORT = qw/check_dependencies/;
our @EXPORT_OK = qw/check_dependencies_opts check_dependencies_reqs/;
our %EXPORT_TAGS = (all => [ @EXPORT, @EXPORT_OK ] );

use CPAN::Meta 2.120920;
use CPAN::Meta::Check 0.007 qw/check_requirements requirements_for/;
use List::Util qw/first/;
use Test::Builder;

my $builder = Test::Builder->new;

my %level_of = (
	requires   => 0,
	classic    => 1,
	recommends => 2,
	suggests   => 3,
);

sub check_dependencies {
	my $level = $level_of{shift || 'classic'};
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	my $metafile = first { -e $_ } qw/MYMETA.json MYMETA.yml META.json META.yml/ or return $builder->ok(0, "No META information provided\n");
	my $meta = CPAN::Meta->load_file($metafile);
	check_dependencies_opts($meta, $_, 'requires') for qw/configure build test runtime/;
	check_dependencies_opts($meta, 'runtime', 'conflicts') if $level >= $level_of{classic};
	if ($level >= $level_of{recommends}) {
		$builder->todo_start('recommends are not mandatory');
		check_dependencies_opts($meta, $_, 'recommends') for qw/configure build test runtime/;
		$builder->todo_end();

		if ($level >= $level_of{suggests}) {
			$builder->todo_start('suggests are not mandatory');
			check_dependencies_opts($meta, $_, 'suggests') for qw/configure build test runtime/;
			$builder->todo_end();
		}
	}
	check_dependencies_opts($meta, 'develop', 'requires') if $ENV{AUTHOR_TESTING};

	return;
}

sub check_dependencies_opts {
	my ($meta, $phases, $type) = @_;

	my $reqs = requirements_for($meta, $phases, $type);
	check_dependencies_reqs($reqs, $type);
}

sub check_dependencies_reqs {
	my ($reqs, $type) = @_;

	my $raw = $reqs->as_string_hash;
	my $ret = check_requirements($reqs, $type);

	local $Test::Builder::Level = $Test::Builder::Level + 1;
	for my $module (sort keys %{$ret}) {
		$builder->ok(!defined $ret->{$module}, "$module satisfies '" . $raw->{$module} . "'")
			or $builder->diag($ret->{$module});
			# Note: when in a TODO, diag behaves like note
	}
	return;
}
    
1;

#ABSTRACT: Check for presence of dependencies

=head1 SYNOPSIS

 use Test::More 0.94;
 use Test::CheckDeps 0.007;
 
 check_dependencies();

 done_testing();

=head1 DESCRIPTION

This module adds a test that assures all dependencies have been installed properly. If requested, it can bail out all testing on error.

=func check_dependencies( [ level ])

Check dependencies based on a local MYMETA or META file.

The C<level> argument is optional. It can be one of:

=over 4

=item * requires

All 'requires' dependencies are checked (the configure, build, test and
runtime phases are always checked, and the develop phase is also tested when
AUTHOR_TESTING is set)

=item * classic

As C<requires>, but 'conflicts' dependencies are also checked.

=item * recommends

As C<classic>, but 'recommends' dependencies are also checked, as TODO tests.

=item * suggests

As C<recommends>, but 'suggests' dependencies are also checked, as TODO tests.

=back

When not provided, C<level> defaults to C<classic> ('requires' and 'conflicts'
dependencies are checked).

=func check_dependencies_opts($meta, $phase, $type)

Check dependencies in L<CPAN::Meta> object $meta for phase C<$phase> (configure, build, test, runtime, develop) and type C<$type>(requires, recommends, suggests, conflicts). You probably just want to use C<check_dependencies> though.

=func check_dependencies_reqs($reqs, $type)

Checks dependencies in a L<CPAN::Meta::Requirements> object $reqs for type
C<$type>(requires, recommends, suggests, conflicts). Allows for usage with
Module::CPANfile or anything which can generate a CPAN::Meta::Requirements
object.

=head1 EXAMPLES

Following are some more advanced usages for this module

=head2 cpanfile

Using check_dependencies_reqs, you can check the dependencies which are
declared in a cpanfile in the root of the checkout. An example usage follows,
and can be deployed with very little customisation needed.

 # file: t/test-dependencies.t
 use strict;
 use warnings;

 use FindBin qw/ $Bin /;

 use Test::More;
 use Test::CheckDeps qw/ check_dependencies_reqs /;
 use Module::CPANfile;

 # Which phases to test
 my $phases = [
  'runtime',
  'build',
 ];

 my $file = Module::CPANfile->load("$Bin/../cpanfile");

 check_dependencies_reqs(
  $file->prereqs->merged_requirements( $phases )
 );

 done_testing;

See L<Module::CPANfile> for cpanfile documentation, and L<CPAN::Meta::Prereqs>
for the options for merged_requirements.

=cut
# vim: set ts=2 sw=2 noet nolist :
