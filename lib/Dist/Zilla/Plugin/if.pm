use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package Dist::Zilla::Plugin::if;

our $VERSION = '0.001000';

# ABSTRACT: Load a plugin only if a condition is true

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moose qw( has around with );
use MooX::Lsub qw( lsub );

with 'Dist::Zilla::Role::Plugin';

has plugin => ( is => ro =>, required => 1 );

lsub plugin_name => sub { my ($self) = @_; return $self->plugin; };

lsub plugin_minversion => sub { return 0 };

lsub conditions => sub { [] };

lsub plugin_arguments => sub { [] };

sub mvp_aliases { return { '-' => 'plugin_arguments' }};
sub mvp_multivalue_args { return qw( plugin_arguments ) }

around 'dump_config' => sub  {
  my ( $orig,  $self, @args ) = @_;
  my $config = $self->$orig( @args );
  my $own_payload = {
    plugin => $self->plugin,
    plugin_name => $self->plugin_name,
    plugin_minversion => $self->plugin_minversion,
    conditions => $self->conditions,
    plugin_arguments => $self->plugin_arguments,
  };
  $config->{ __PACKAGE__ } = $own_payload;
  return $config;
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
  plugin            = Git::Contributors
  plugin_name       = KNL/Git::Contributors
  plugin_minversion = 0.010
  condition = -e $root . '.git'
  condition = -e $root . '.git/config'
  -= include_authors = 1
  -= include_releaser = 0
  -= order_by = name

=head1 DESCRIPTION

C<if> is intended to be a similar utility to L<< perl C<if>|if >>.

It will execute all of C<condition> in turn, and only when all return true, will the plugin
be added to C<Dist::Zilla>

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
