
use strict;
use warnings;

use Test::More;

# ABSTRACT: A basic test

use Test::DZil qw( simple_ini );
use Dist::Zilla::Util::Test::KENTNL 1.001 qw( dztest );
use Test::Differences;

my $t = dztest();
$t->add_file( 'dist.ini', simple_ini( ['MetaConfig'], [ 'if' => { dz_plugin => 'GatherDir' } ], ) );
$t->build_ok;

$t->meta_path_deeply(
  '/x_Dist_Zilla/plugins/*[ value->{class} !~ /Dist::Zilla::Plugin::FinderCode/ ]/*[key eq q[class]]',
  [ 'Dist::Zilla::Plugin::MetaConfig', 'Dist::Zilla::Plugin::GatherDir', 'Dist::Zilla::Plugin::if', ],
);
my $file = $t->test_has_built_file('dist.ini');
done_testing;
