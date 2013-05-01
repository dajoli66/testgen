use Module::Build;
my $build = Module::Build->new(
  module_name => 'Test::Generated',
  license     => 'perl',
  requires    => {
    'perl'          => '5.6.1',
    'Test::Class'   => '0.36',
    'MRO::Compat'   => '0.11',
    'Perl6::Slurp'  => '0.03',
    'Perl6::Export' => '0.07',
    'Sub::Name'     => '0.04',
    'YAML::XS'      => '0.37',
  },
);
$build->create_build_script;
