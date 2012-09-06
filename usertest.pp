user { 'jeff':
  ensure   => present,
  groups   => ['admin', 'garysgroupwithspaces', 'groupy'],
  password => '7ea7d592131f57b2c8f8bdbcec8d9df12128a386393a4f00c7619bac2622a44d451419d11da512d5915ab98e39718ac94083fe2efd6bf710a54d477f8ff735b12587192d',
}
user { 'dagobah':
  ensure   => present,
  gid      => staff,
  password => '7ea7d592131f57b2c8f8bdbcec8d9df12128a386393a4f00c7619bac2622a44d451419d11da512d5915ab98e39718ac94083fe2efd6bf710a54d477f8ff735b12587192d',
  comment  => "Dagobah",
  groups   => ['garysgroupwithspaces', 'groupy', 'staff'],
}
#user { 'slagador': ensure => present }

