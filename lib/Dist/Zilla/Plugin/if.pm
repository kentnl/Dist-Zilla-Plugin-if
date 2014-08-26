use 5.010;    #  _Pulp__5010_qr_m_propagate_properly
use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::if;

our $VERSION = '0.001000';

# ABSTRACT: Load a plugin only if a condition is true

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moose qw( has around with );
use MooX::Lsub qw( lsub );
use Dist::Zilla::Util qw();
use Eval::Closure qw( eval_closure );
use Dist::Zilla::Util::ConfigDumper qw( config_dumper );

with 'Dist::Zilla::Role::PrereqSource';













has dz_plugin => ( is => ro =>, required => 1 );



















lsub dz_plugin_name => sub { my ($self) = @_; return $self->dz_plugin; };









lsub dz_plugin_minversion => sub { return 0 };





































lsub conditions => sub { [] };

































lsub dz_plugin_arguments => sub { [] };




















lsub prereq_to => sub { ['develop.requires'] };









lsub dz_plugin_package => sub {
  my ($self) = @_;
  return Dist::Zilla::Util->expand_config_package_name( $self->dz_plugin );
};

around 'dump_config' => config_dumper( __PACKAGE__,
  qw( dz_plugin dz_plugin_name dz_plugin_package dz_plugin_minversion conditions dz_plugin_arguments prereq_to ) );

sub mvp_aliases {
  return {
    q{>}                  => 'dz_plugin_arguments',
    q[dz_plugin_argument] => 'dz_plugin_arguments',
    q{?}                  => 'conditions',
    q[condition]          => 'conditions',
  };
}

sub mvp_multivalue_args {
  return qw( dz_plugin_arguments prereq_to conditions );
}

my $re_phases   = qr/configure|build|test|runtime|develop/msx;
my $re_relation = qr/requires|recommends|suggests|conflicts/msx;
my $re_prereq   = qr/\A($re_phases)[.]($re_relation)\z/msx;








sub register_prereqs {
  my ($self) = @_;
  my $prereqs = $self->zilla->prereqs;

  my @targets;

  for my $prereq ( @{ $self->prereq_to } ) {
    next if 'none' eq $prereq;
    if ( my ( $phase, $relation ) = $prereq =~ $re_prereq ) {
      push @targets, $prereqs->requirements_for( $phase, $relation );
    }
  }
  for my $target (@targets) {
    $target->add_string_requirement( $self->dz_plugin_package, $self->dz_plugin_minversion );
  }
  return;
}

sub _split_ini_token {
  my ( undef, $token ) = @_;
  my ( $key,  $value ) = $token =~ /\A\s*([^=]+?)\s*=\s*(.+?)\s*\z/msx;
  return ( $key, $value );
}
















sub check_conditions {
  my ($self) = @_;

  my $env = {};
  ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
  $env->{q[$root]}  = \$self->zilla->root;
  $env->{q[$zilla]} = \$self->zilla;
  my $code = join q[ and ], @{ $self->conditions }, q[1];
  my $closure = eval_closure(
    source      => qq[sub { \n] . $code . qq[}\n],
    environment => $env,
  );
  ## use critic;
  return $closure->();
}

# This hooks in if's ->finalize step
# and conditionally creates a child plugin,
# which, itself, is finalized, and added to $zilla->plugins
# prior to this plugin completing finalization.
around 'plugin_from_config' => sub {
  my ( $orig, $plugin_class, $name, $arg, $if_section ) = @_;
  my $if_obj = $plugin_class->$orig( $name, $arg, $if_section );

  return $if_obj unless $if_obj->check_conditions;

  # Here is where we construct the conditional plugin
  my $assembler     = $if_section->sequence->assembler;
  my $child_section = $assembler->section_class->new(
    name     => $if_obj->dz_plugin_name,
    package  => $if_obj->dz_plugin_package,
    sequence => $if_section->sequence,
  );

  # Here is us, adding the arguments to that plugin
  for my $argument ( @{ $if_obj->dz_plugin_arguments } ) {
    $child_section->add_value( $if_obj->_split_ini_token($argument) );
  }
  ## And this is where the assembler injects into $zilla->plugins!
  $child_section->finalize();

  return $if_obj;
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::if - Load a plugin only if a condition is true

=head1 VERSION

version 0.001000

=head1 SYNOPSIS

  [if / FooLoader]
  dz_plugin            = Git::Contributors
  dz_plugin_name       = KNL/Git::Contributors
  dz_plugin_minversion = 0.010
  ?= -e $root . '.git'
  ?= -e $root . '.git/config'
  >= include_authors = 1
  >= include_releaser = 0
  >= order_by = name

=head1 DESCRIPTION

C<if> is intended to be a similar utility to L<< perl C<if>|if >>.

It will execute all of C<condition> in turn, and only when all return true, will the plugin
be added to C<Dist::Zilla>

=head1 METHODS

=head2 C<register_prereqs>

By default, registers L</dz_plugin_package> version L</dz_plugin_minimumversion>
as C<develop.requires> ( as per L</prereq_to> ).

=head2 check_conditions

Compiles C<conditions> into a single sub and executes it.

  conditions = y and foo
  conditions = x blah 

Compiles as 

  sub { y and foo and x blah and 1 }

But with C<$root> and C<$zilla> in scope.

=head1 ATTRIBUTES

=head2 C<dz_plugin>

B<REQUIRED>

The C<plugin> identifier.

For instance, C<[GatherDir / Foo]> and C<[GatherDir]> approximation would both set this field to

  dz_plugin => 'GatherDir'

=head2 C<dz_plugin_name>

The "Name" for the C<plugin>.

For instance, C<[GatherDir / Foo]> would set this value as

  dz_plugin_name => "Foo"

and C<[GatherDir]> approximation would both set this field to

  dz_plugin_name => "Foo"

In Dzil, C<[GatherDir]> is equivalent to C<[GatherDir / GatherDir]>.

Likewise, if you do not specify C<dz_plugin_name>, the value of C<dz_plugin> will be used.

=head2 C<dz_plugin_minversion>

The minimum version of C<dz_plugin> to use.

At present, this B<ONLY> affects C<prereq> generation.

=head2 C<conditions>

A C<mvp_multivalue_arg> attribute that creates an array of conditions
that must all evaluate to true for the C<dz_plugin> to be injected.

These values are internally simply joined with C<and> and executed in an C<Eval::Closure>

Two variables are defined in scope for your convenience:

=over 4

=item * C<$zilla> - The Dist::Zilla builder object itself

=item * C<$root> - The same as C<< $zilla->root >> only more convenient.

=back

For added convenience, this attribute has an alias of '?' ( nmemonic "Test" ), so the following are equivalent:

  [if]
  dz_plugin_name = Foo
  ?= exists $ENV{loadfoo}
  ?= !!$ENV{loadfoo}

  [if]
  dz_plugin_name = Foo
  condition = exists $ENV{loadfoo}
  condition = !!$ENV{loadfoo}

  [if]
  dz_plugin_name = Foo
  conditions = exists $ENV{loadfoo}
  conditions = !!$ENV{loadfoo}

=head2 C<dz_plugin_arguments>

A C<mvp_multivalue_arg> attribute that creates an array of arguments 
to pass on to the created plugin.

For convenience, this attribute has an alias of '>' ( nmenonic "Forward" ), so that the following example:

  [GatherDir]
  include_dotfiles = 1
  exclude_file = bad
  exclude_file = bad2

Would be written

  [if]
  dz_plugin = GatherDir
  ?= $ENV{dogatherdir}
  >= include_dotfiles = 1
  >= exclude_file = bad
  >= exclude_file = bad2

Or in crazy long form

  [if]
  dz_plugin = GatherDir
  condtion = $ENV{dogatherdir}
  dz_plugin_argument = include_dotfiles = 1
  dz_plugin_argument = exclude_file = bad
  dz_plugin_argument = exclude_file = bad2

=head2 C<prereq_to>

This determines where dependencies get injected.

Default is:

  develop.requires

And a special value

  none

Prevents dependency injection.

This attribute may be specified multiple times.

=head2 C<dz_plugin_package>

This is an implementation detail which returns the expanded name of C<dz_plugin>

You could probably find some evil use for this, but I doubt it.

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
