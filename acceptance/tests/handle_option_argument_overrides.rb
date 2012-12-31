test_name "Allow for overriding options set via --test"

agents.each do |host|
  foo = "file { '/tmp/test-option-overrides': content => 'foo\n' }"
  bar = "file { '/tmp/test-option-overrides': content => 'bar\n' }"

  # Have to run apply twice in order to make sure a diff would be relevant
  on host, puppet_apply("--test --no-show_diff"), :stdin => foo
  on host, puppet_apply("--test --no-show_diff"), :stdin => bar do
    assert_no_match(/^(\+bar|-foo)/), stdout, "should not show a diff in output"
  end
end
