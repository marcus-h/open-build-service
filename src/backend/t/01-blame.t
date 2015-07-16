use strict;
use warnings;

use Test::More tests => 16;

use BSSrcBlame;

our $fixtures_dir = 'fixtures';

sub test_sub {
  my ($test_name, $code_ref, $args, $expected) = @_;
  die("code ref required\n") unless $code_ref;
  is_deeply($code_ref->(@$args), $expected, $test_name);
}

sub array_to_ref {
  return \@_;
}

sub fixture {
  my ($filename) = @_;
  my $dir = __FILE__;
  $dir =~ s/\/[^\/]*$//;
  return "$dir/$fixtures_dir/$filename";
}

sub test_diff3 {
  my ($test_name, $args, @expected) = @_;
  test_sub("diff3: " . $test_name,
    sub { return array_to_ref(BSSrcBlame::diff3(@_)); },
    $args, \@expected);
}

sub test_merge {
  my ($test_name, $args, @expected) = @_;
  test_sub("merge: " . $test_name,
    sub { return array_to_ref(BSSrcBlame::merge(@_)); },
    $args, \@expected);
}

# test cases for BSSrcBlame::diff3

test_diff3("two-way diff of my and /dev/null",
  [fixture('my'), '/dev/null', '/dev/null'],
  (
    {
      'odd' => 0,
      'data' => [
        [0, 11, 'c'],
        [-1, -1, 'a'],
        [-1, -1, 'a']
      ]
    }
  ));

test_diff3("two-way diff of your and common",
  [fixture('your'), fixture('common'), fixture('common')],
  (
    {
      'odd' => 0,
      'data' => [
        [4, 5, 'c'],
        [4, 5, 'c'],
        [4, 5, 'c']
      ]
    },
    {
      'odd' => 0,
      'data' => [
        [10, 12, 'c'],
        [9, 9, 'a'],
        [9, 9, 'a']
      ]
    }
  ));

test_diff3("three-way diff of my, your and common",
  [fixture('my'), fixture('your'), fixture('common')],
  (
    {
      'odd' => 0,
      'data' => [
        [1, 2, 'c'],
        [1, 1, 'c'],
        [1, 1, 'c']
      ]
    },
    {
      'odd' => 1,
      'data' => [
        [5, 6, 'c'],
        [4, 5, 'c'],
        [4, 5, 'c']
      ]
    },
    {
      'odd' => 0,
      'data' => [
        [8, 10, 'c'],
        [7, 8, 'c'],
        [7, 8, 'c']
      ]
    },
    {
      'odd' => 1,
      'data' => [
        [11, 11, 'a'],
        [10, 12, 'c'],
        [9, 9, 'a']
      ]
    }
  ));

test_diff3("empty three-way diff",
  [fixture('my'), fixture('my'), fixture('my')],
  ());

test_diff3("conflict in a three-way diff",
  [fixture('common'), fixture('your'), fixture('my')],
  (
    {
      'odd' => 2,
      'data' => [
        [1, 1, 'c'],
        [1, 1, 'c'],
        [1, 2, 'c']
      ]
    },
    {
      'odd' => 1,
      'data' => [
        [4, 5, 'c'],
        [4, 5, 'c'],
        [5, 6, 'c']
      ]
    },
    {
      'odd' => undef,
      'data' => [
        [7, 9, 'c'],
        [7, 12, 'c'],
        [8, 11, 'c']
      ]
    }
  ));

# test cases for BSSrcBlame::merge

test_merge("my and /dev/null",
  [fixture('my'), '/dev/null', '/dev/null'],
  (
    [0, 0],
    [0, 1],
    [0, 2],
    [0, 3],
    [0, 4],
    [0, 5],
    [0, 6],
    [0, 7],
    [0, 8],
    [0, 9],
    [0, 10],
    [0, 11]
  ));

test_merge("my, your and common",
  [fixture('my'), fixture('your'), fixture('common')],
  (
    [2, 0],
    [0, 1],
    [0, 2],
    [2, 2],
    [2, 3],
    [1, 4],
    [1, 5],
    [2, 6],
    [0, 8],
    [0, 9],
    [0, 10],
    [2, 9],
    [1, 10],
    [1, 11],
    [1, 12]
  ));

test_merge("only changes in the middle of the files (take rest from common)",
  [fixture('my'), fixture('common'), fixture('common')],
  (
    [2, 0],
    [0, 1],
    [0, 2],
    [2, 2],
    [2, 3],
    [2, 4],
    [2, 5],
    [2, 6],
    [0, 8],
    [0, 9],
    [0, 10],
    [2, 9]
  ));

test_merge("/dev/null /dev/null common",
  ['/dev/null', '/dev/null', fixture('common')],
  ());

test_merge("no changes (real file)",
  [fixture('my'), fixture('my'), fixture('my')],
  (
    [2, 0],
    [2, 1],
    [2, 2],
    [2, 3],
    [2, 4],
    [2, 5],
    [2, 6],
    [2, 7],
    [2, 8],
    [2, 9],
    [2, 10],
    [2, 11]
  ));

test_merge("no changes (/dev/null)",
  ['/dev/null', '/dev/null', '/dev/null'],
  ());

test_merge("numlines for the common file",
  [fixture('my'), fixture('common'), fixture('common'), 9],
  (
    [2, 0],
    [0, 1],
    [0, 2],
    [2, 2],
    [2, 3],
    [2, 4],
    [2, 5],
    [2, 6],
    [0, 8],
    [0, 9],
    [0, 10],
    [2, 9]
  ));

test_merge("numlines for the common file (one line less)",
  [fixture('my'), fixture('common'), fixture('common'), 8],
  (
    [2, 0],
    [0, 1],
    [0, 2],
    [2, 2],
    [2, 3],
    [2, 4],
    [2, 5],
    [2, 6],
    [0, 8],
    [0, 9],
    [0, 10]
  ));

test_merge("pretend that the common file comprises one line (numlines 0)",
  [fixture('my'), fixture('my'), fixture('my'), 0],
  (
    [2, 0]
  ));

test_merge("pretend that the common file is empty (numlines -1)",
  [fixture('my'), fixture('my'), fixture('my'), -1],
  ());

test_merge("conflict",
  [fixture('common'), fixture('your'), fixture('my')],
  undef);
