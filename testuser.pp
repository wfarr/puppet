user { 'testuser':
  ensure    => 'present',
  comment   => 'testuser',
  home      => '/Users/testuser',
  password  => 'b5b66261296695d4a530bd3e1fa59524b5aabe534015fd2838f11b89abe33a3dbf1a9ae8c84bf56ce7cac52a5e485047f6426ae2090fe1df093fbec9e411731983f2c95e',
  #password => 'B5B66261296695D4A530BD3E1FA59524B5AABE534015FD2838F11B89ABE33A3DBF1A9AE8C84BF56CE7CAC52A5E485047F6426AE2090FE1DF093FBEC9E411731983F2C95E',
  shell     => '/bin/bash',
  uid       => '1000',
}
