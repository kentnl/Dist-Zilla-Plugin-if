
use strict;
use warnings;

use Test::More;

# ABSTRACT: A basic test

use Test::DZil qw( simple_ini );
use Dist::Zilla::Util::Test::KENTNL 1.001 qw( dztest );
use Test::Differences;

my $t = dztest();
$t->add_file( '.dotfile', q[adotfile] );
$t->add_file( 'bad1',     q[abadfile] );
$t->add_file( 'bad2',     q[abadfile] );
$t->add_file( 'good',     q[agoodfile] );

$t->add_file(
  'dist.ini',
  simple_ini(
    ['MetaConfig'],
    [
      'if' => {
        dz_plugin => 'GatherDir',
        dz_plugin_arguments =>
          [ 'include_dotfiles = 1', 'exclude_filename = bad1', 'exclude_filename = bad2', 'exclude_filename = bad 3', ]
      }
    ],
  )
);
$t->build_ok;

$t->meta_path_deeply(
  '/x_Dist_Zilla/plugins/*[ value->{class} !~ /Dist::Zilla::Plugin::FinderCode/ ]/*[key eq q[class]]',
  [ 'Dist::Zilla::Plugin::MetaConfig', 'Dist::Zilla::Plugin::GatherDir', 'Dist::Zilla::Plugin::if', ],
);
my $plugin = $t->builder->plugin_named('GatherDir');

eq_or_diff( $plugin->exclude_filename, [ 'bad1', 'bad2', 'bad 3' ] );

$t->test_has_built_file('dist.ini');
$t->test_has_built_file('.dotfile');
$t->test_has_built_file('good');
done_testing;
