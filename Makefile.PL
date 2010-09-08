use inc::Module::Install;
name 'Module-Install-TestAssemble';
all_from 'lib/Module/Install/TestAssemble.pm';

requires 'Module::Install' => 1.00;

test_requires 'Test::More', 0.88;
#test_requires 'Test::Requires';

tests_recursive 't';
author_tests 'xt';

auto_include();
auto_set_repository();

WriteAll;
