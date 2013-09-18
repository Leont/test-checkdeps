package Test::CheckDeps;
use strict;
use warnings FATAL => 'all';

use Exporter 5.57 'import';
our @EXPORT = qw/check_dependencies/;
our @EXPORT_OK = qw/check_dependencies_opts/;
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
	my $metafile = first { -e $_ } qw/MYMETA.json MYMETA.yml META.json META.yml/ or return $builder->ok(0, "No META information provided\n");
	my $meta = CPAN::Meta->load_file($metafile);
	check_dependencies_opts($meta, $_, 'requires') for qw/configure build test runtime/;
	check_dependencies_opts($meta, 'runtime', 'conflicts') if $level > 0;
	if ($level > 1) {
		$builder->todo_start('recommends are not mandatory');
		check_dependencies_opts($meta, $_, 'recommends') for qw/configure build test runtime/;
		$builder->todo_end();

		if ($level > 2) {
			$builder->todo_start('suggests are not mandatory');
			check_dependencies_opts($meta, $_, 'suggests') for qw/configure build test runtime/;
			$builder->todo_end();
		}
	}
	return;
}

sub check_dependencies_opts {
	my ($meta, $phases, $type) = @_;

	my $reqs = requirements_for($meta, $phases, $type);
	my $raw = $reqs->as_string_hash;
	my $ret = check_requirements($reqs, $type);

	for my $module (sort keys %{$ret}) {
		$builder->ok(!defined $ret->{$module}, "$module satisfies '" . $raw->{$module} . "'")
			or $builder->diag($ret->{$module});
			# Note: when in a TODO, diag behaves like note
	}
	return;
}

1;

#ABSTRACT: Check for presence of dependencies

__END__

=head1 DESCRIPTION

This module adds a test that assures all dependencies have been installed properly. If requested, it can bail out all testing on error.

=func check_dependencies( [ level ])

Check dependencies based on a local MYMETA or META file.

The C<level> argument is optional. It can be one of:

=over 4

=item * requires

All 'requires' dependencies are checked (for the configure, build, test and
runtime phases)

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

=cut
# vi:noet:sts=2:sw=2:ts=2
