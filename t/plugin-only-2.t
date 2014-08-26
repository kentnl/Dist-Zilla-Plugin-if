
use strict;
use warnings;

use Test::More;

# ABSTRACT: A basic test

use Test::DZil qw( simple_ini );
use Dist::Zilla::Util::Test::KENTNL 1.001 qw( dztest );
use Test::Differences;

my $t = dztest();
$t->add_file( 'dist.ini', simple_ini( [ 'if' => { dz_plugin => 'MetaConfig' } ], ) );
$t->build_ok;

$t->meta_path_deeply(
  '/x_Dist_Zilla/plugins/*[ value->{class} !~ /Dist::Zilla::Plugin::FinderCode/ ]/*[key eq q[class]]',
  [ 'Dist::Zilla::Plugin::MetaConfig', 'Dist::Zilla::Plugin::if', ],
);
done_testing;
