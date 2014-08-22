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
use Dist::Zilla::Util qw();
use Eval::Closure qw( eval_closure );

with 'Dist::Zilla::Role::PrereqSource';

has plugin => ( is => ro =>, required => 1 );

lsub plugin_name => sub { my ($self) = @_; return $self->plugin; };

lsub plugin_minversion => sub { return 0 };

lsub conditions => sub { [] };

lsub plugin_arguments => sub { [] };

lsub prereq_to => sub { ['develop.requires'] };

lsub plugin_package => sub {
    my ($self) = @_;
    return Dist::Zilla::Util->expand_config_package_name( $self->plugin );
};

sub mvp_aliases {
    return {
        '>' => 'plugin_arguments',
        '?' => 'conditions',
    };
}
sub mvp_multivalue_args { return qw( plugin_arguments prereq_to conditions ) }

my $re_phases   = qr/configure|build|test|runtime|develop/msx;
my $re_relation = qr/requires|recommends|suggests|conflicts/msx;
my $re_prereq   = qr/\A($re_phases)[.]($re_relation)\z/msx;

sub register_prereqs {
    my ($self) = @_;
    my $prereqs = $self->zilla->prereqs;

    my @targets;

    for my $prereq ( @{ $self->prereq_to } ) {
        if ( my ( $phase, $relation ) = $prereq =~ $re_prereq ) {
            push @targets, $prereqs->requirements_for( $phase, $relation );
        }
    }
    for my $target (@targets) {
        $target->add_string_requirement( $self->plugin_package,
            $self->plugin_minversion );
    }
    return;
}

sub _split_ini_token {
    my ( $self, $token ) = @_;
    my ( $key,  $value ) = $token =~ /\A\s*([^=]+?)\s*=\s*(.+?)\s*\z/msx;
    return ( $key, $value );
}

sub check_conditions {
    my ($self) = @_;

    my $env = {};
    $env->{q[$root]}  = \$self->zilla->root;
    $env->{q[$zilla]} = \$self->zilla;
    my $code = join qq[ and ], @{ $self->conditions };
    my $closure = eval_closure(
        source      => qq[sub { \n] . $code . qq[}\n],
        environment => $env,
    );
    return $closure->();
}

around 'dump_config' => sub {
    my ( $orig, $self, @args ) = @_;
    my $config      = $self->$orig(@args);
    my $own_payload = {
        plugin            => $self->plugin,
        plugin_package    => $self->plugin_package,
        plugin_name       => $self->plugin_name,
        plugin_minversion => $self->plugin_minversion,
        conditions        => $self->conditions,
        plugin_arguments  => $self->plugin_arguments,
        prereq_to         => $self->prereq_to,
    };
    $config->{__PACKAGE__} = $own_payload;
    return $config;
};

# This hooks in if's ->finalize step
# and conditionally creates a child plugin,
# which, itself, is finalized, and added to $zilla->plugins
# prior to this plugin completing finalization.
around 'plugin_from_config' => sub {
    my ( $orig, $plugin_class, $name, $arg, $if_section ) = @_;
    my $if_obj = $plugin_class->$orig( $name, $arg, $if_section );
    
    return $if_obj unless $if_obj->check_conditions;

    # Here is where we construct the conditional plugin
    my $child_section = $if_section->sequence->assembler->section_class->new(
        name     => $if_obj->plugin_name,
        package  => $if_obj->plugin_package,
        sequence => $if_section->sequence,
    );
    # Here is us, adding the arguments to that plugin
    for my $argument ( @{ $if_obj->plugin_arguments } ) {
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
  plugin            = Git::Contributors
  plugin_name       = KNL/Git::Contributors
  plugin_minversion = 0.010
  ?= -e $root . '.git'
  ?= -e $root . '.git/config'
  >= include_authors = 1
  >= include_releaser = 0
  >= order_by = name

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
