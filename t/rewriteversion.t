use strict;
use warnings;
use File::Path;
use File::Temp;
use Path::Tiny;
use Test::More;

use App::RewriteVersion;

my $app = App::RewriteVersion->new;

# Defaults
ok !$app->allow_decimal_underscore, 'right default';
ok !$app->dry_run, 'right default';
ok !$app->follow_symlinks, 'right default';
ok !$app->global, 'right default';
ok !$app->verbose, 'right default';

# Set options
ok $app->allow_decimal_underscore(1)->allow_decimal_underscore, 'option set';
ok $app->dry_run(1)->dry_run, 'option set';
ok $app->follow_symlinks(1)->follow_symlinks, 'option set';
ok $app->global(1)->global, 'option set';
ok $app->verbose(1)->verbose, 'option set';

$app = App::RewriteVersion->new;

# Bump version
is $app->bump_version('1.0'), '1.1', 'right version';
is $app->bump_version('v1.0.0'), 'v1.0.1', 'right version';
is $app->bump_version('1.9'), '2.0', 'right version';
is $app->bump_version('v1.0.9'), 'v1.0.10', 'right version';

ok !eval { $app->bump_version('1.2.3'); 1 }, 'invalid version';
ok !eval { $app->bump_version('v1.2'); 1 }, 'invalid version';

ok !eval { $app->bump_version('1.0_1'); 1 }, 'decimal underscore version is invalid';
is $app->allow_decimal_underscore(1)->bump_version('1.0_1'), '1.0_2', 'right version';
$app->allow_decimal_underscore(0);

is $app->bump_version('1.0', sub { '5.0' }), '5.0', 'right version';
is $app->bump_version('1.0', sub { $_[0] =~ s/^(\d+)/$1+1/e; $_[0] }), '2.0', 'right version';

# Set up a fake dist
my $dir = File::Temp->newdir;
my $dist = path("$dir/Foo-Bar");
$dist->mkpath;
path("$dist/lib/Foo")->mkpath;
my $module = path("$dist/lib/Foo/Bar.pm");
$module->spew_utf8(qq{package Foo::Bar;\nour \$VERSION = '1.01';\n});
my $module2 = path("$dist/lib/Foo.pm");
$module2->spew_utf8(qq{package Foo;\nour \$VERSION = '1.0';\n});
my $module3 = path("$dist/lib/Foo/Baz.pm");
$module3->spew_utf8(qq{package Foo::Baz;\n});
my $module4 = path("$dist/lib/Foo/Foo.pm");
$module4->spew_utf8(qq{package Foo::Foo;\nour \$VERSION = '1.2_3';\n});

# Read version
is $app->version_from($module), '1.01', 'right version';
is $app->version_from($module3), undef, 'no version';

# Dist version
is $app->current_version(dir => $dist), '1.01', 'right version';
is $app->current_version(file => $module), '1.01', 'right version';
ok !eval { $app->current_version(file => $module3); 1 }, 'no version';

# Rewrite version
ok $app->rewrite_version($module, '1.20'), 'rewrote version';
is $app->version_from($module), '1.20', 'right version';
ok $app->rewrite_version($module, 'v1.2.3'), 'rewrote version';
is $app->version_from($module), 'v1.2.3', 'right version';
ok $app->rewrite_version($module, '1.01', is_trial => 1), 'rewrote version';
is $app->version_from($module), '1.01', 'right version';

ok !$app->rewrite_version($module3, '1.5'), 'no version';
ok !eval { $app->rewrite_version($module, '1.2.3'); 1 }, 'invalid version';
ok !eval { $app->rewrite_version($module, 'v1.2'); 1 }, 'invalid version';

# Decimal underscore
ok !eval { $app->rewrite_version($module, '1.2_3'); 1 }, 'decimal underscore version is invalid';
ok $app->allow_decimal_underscore(1)->rewrite_version($module, '1.2_3'), 'decimal underscore version is valid';
$app->allow_decimal_underscore(0);

# Rewrite all versions
$app->rewrite_versions('1.20', dir => $dist);
is $app->current_version(dir => $dist), '1.20', 'right version';
is $app->version_from($module), '1.20', 'right version';
is $app->version_from($module2), '1.20', 'right version';
is $app->version_from($module3), undef, 'right version';
is $app->version_from($module4), '1.20', 'right version';

$app->rewrite_versions('v1.2.3', dir => $dist, is_trial => 1);
is $app->current_version(dir => $dist), 'v1.2.3', 'right version';
is $app->version_from($module), 'v1.2.3', 'right version';
is $app->version_from($module2), 'v1.2.3', 'right version';
is $app->version_from($module3), undef, 'right version';
is $app->version_from($module4), 'v1.2.3', 'right version';

ok !eval { $app->rewrite_versions('1.2.3', dir => $dist); 1 }, 'invalid version';
ok !eval { $app->rewrite_versions('v1.2', dir => $dist); 1 }, 'invalid version';

ok !eval { $app->rewrite_versions('1.2_3', dir => $dist); 1 }, 'decimal underscore version is invalid';
$app->allow_decimal_underscore(1)->rewrite_versions('1.2_3', dir => $dist);
is $app->current_version(dir => $dist), '1.2_3', 'right version';
is $app->version_from($module), '1.2_3', 'right version';
is $app->version_from($module2), '1.2_3', 'right version';
is $app->version_from($module3), undef, 'right version';
is $app->version_from($module4), '1.2_3', 'right version';
$app->allow_decimal_underscore(0);

$app->rewrite_versions('v1.2.3', dir => $dist);
is $app->current_version(dir => $dist), 'v1.2.3', 'right version';

my $version_str = quotemeta q{our $VERSION = 'v1.2.3';};
like $module->slurp_utf8, qr/$version_str/, 'contains version string';
like $module2->slurp_utf8, qr/$version_str/, 'contains version string';
unlike $module3->slurp_utf8, qr/$version_str/, 'doesnt contain version string';
like $module4->slurp_utf8, qr/$version_str/, 'contains version string';

done_testing;
