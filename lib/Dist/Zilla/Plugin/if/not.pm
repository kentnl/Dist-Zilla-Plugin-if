use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::if::not;

# ABSTRACT: Only load a plugin if a condition is false

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moose qw( has around with );
use MooX::Lsub qw( lsub );
use Dist::Zilla::Util qw();
use Eval::Closure qw( eval_closure );
use Dist::Zilla::Util::ConfigDumper qw( config_dumper );

with 'Dist::Zilla::Role::PluginLoader::Configurable';

lsub conditions => sub { [] };

around 'dump_config' => config_dumper( __PACKAGE__, qw( conditions ) );

around mvp_aliases => sub {
  my ( $orig, $self, @rest ) = @_;
  my $hash = $self->$orig(@rest);
  $hash = {
    %{$hash},
    q{?}         => 'conditions',
    q[condition] => 'conditions',
  };
  return $hash;
};
around mvp_multivalue_args => sub {
  my ( $orig, $self, @args ) = @_;
  return ( qw( conditions ), $self->$orig(@args) );
};

sub check_conditions {
  my ($self) = @_;

  my $env = {};
  ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
  $env->{q[$root]}  = \$self->zilla->root;
  $env->{q[$zilla]} = \$self->zilla;
  my $code = join q[ and ], @{ $self->conditions }, q[1];
  my $closure = eval_closure(
    source      => qq[sub {  \n] . $code . qq[ }\n],
    environment => $env,
  );
  ## use critic;
  return $closure->();
}

around 'load_plugins' => sub {
  my ( $orig, $self, $loader ) = @_;
  return if $self->check_conditions;
  return $self->$orig($loader);
};

no Moose;

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::if::not - Only load a plugin if a condition is false

=head1 VERSION

version 0.001001

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
