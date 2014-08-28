
use strict;
use warnings;

use Test::More;

# ABSTRACT: A basic test

use Test::DZil qw( simple_ini );
use Dist::Zilla::Util::Test::KENTNL 1.001 qw( dztest );

my $t = dztest();
$t->add_file( 'dist.ini', simple_ini( [ 'if::not' => {} ] ) );
isnt( $t->safe_configure, undef, "Configure fails without plugin" );

done_testing;

