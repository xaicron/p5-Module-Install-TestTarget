use inc::Module::Install;
name 'Module-Install-TestAssembler';
all_from 'lib/Module/Install/TestAssembler.pm';

#requires '';

build_requires 'Test::More', 0.88;
#test_requires 'Test::Requires';

tests_recursive 't';
author_tests 'xt';

auto_include();
auto_set_repository();

WriteAll;
