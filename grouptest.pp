group { 'garygroup':
  ensure  => present,
  members => ['gary', 'jeff', 'dagobah', 'notauser'],
}
