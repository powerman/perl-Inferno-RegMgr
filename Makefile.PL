use inc::Module::Install;

name     'Inferno-RegMgr';
all_from 'lib/Inferno/RegMgr.pm';
author   'Alex Efros <powerman-asdf@ya.ru>';
license  'perl';

requires 'version';
requires 'Perl6::Export::Attrs';
requires 'EV';
requires 'IO::Stream';

build_requires 'Test::More';
build_requires 'Test::Exception';

auto_install;

WriteAll;

