package BSBlameTest;

use strict;
use warnings;
use Data::Dumper;
use Digest::MD5 ();
use Test::More;

use BSRPC;
use BSXML;
use BSXPath;
use BSConfig;
use BSUtil;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(blame_is list_like commit branch create del list);

## test helpers

sub blame_is {
  my ($test_name, $projid, $packid, $filename, %opts) = @_;
  my $code = delete $opts{'code'} || 200;
  die("'expected' option required\n") unless exists $opts{'expected'} || $code != 200;
  my $exp = delete $opts{'expected'};
  my $res;
  eval {
#    list($projid, $packid);
    $res = getfile($projid, $packid, $filename, 'expand' => 1, %opts);
  };
  if ($code && $code != 200) {
    like($@, qr/^$code/, $test_name);
    return;
  }
#  is($projid, $exp, $test_name);
#  ok(1, $test_name);
  $exp =~ s/^[^:]*: //gm;
  is($res, $exp, $test_name);
}

sub list_like {
  my ($test_name, $projid, $packid, %opts) = @_;
  die("'xpath' option required\n") unless exists $opts{'xpath'};
  my $xpath = delete $opts{'xpath'};
  my $dir = list($projid, $packid, hash2query(%opts));
  my $match = BSXPath::match($dir, $xpath);
  ok(@$match, $test_name);
}

## helpers

# add User-Agent header (unless present), because if the BSRPC UA is used,
# the backend might use different codepath (even though this shouldn't harm...)
sub rpc {
  my ($uri, @args) = @_;
  $uri = {'uri' => $uri} unless ref($uri) eq 'HASH';
  push @{$uri->{'headers'}}, "User-Agent: BSBlameTest" unless grep { /'^User-Agent:'/si } @{$uri->{'headers'} || []};
  return BSRPC::rpc($uri, @args);
}

# eek: ls is already imported from BSUtil
sub list {
  my ($projid, $packid, @query) = @_;
  my $uri = "$BSConfig::srcserver/source/$projid";
  $uri .= "/$packid" if $packid;
  return rpc($uri, $BSXML::dir, @query);
}

sub getfile {
  my ($projid, $packid, $filename, %opts) = @_;
  return rpc("$BSConfig::srcserver/source/$projid/$packid/$filename", undef, hash2query(%opts));
}

sub putdata {
  my ($uri, $dtd, $data, @query) = @_;
  my $param = {
    'uri' => $uri,
    'request' => 'PUT',
    'data' => $data,
    'headers' => [ 'Content-Type: application/octet-stream' ]
  };
  return rpc($param, $dtd, @query);
}

sub putfile {
  my ($projid, $packid, $filename, $data, @query) = @_;
  my $uri = "$BSConfig::srcserver/source/$projid/$packid/$filename";
  return putdata($uri, $BSXML::revision, $data, @query);
  }

sub putproject {
  my ($projid, @query) = @_;
  my $uri = "$BSConfig::srcserver/source/$projid/_meta";
  my $data = BSUtil::toxml({'name' => $projid}, $BSXML::proj);
  return putdata($uri, $BSXML::proj, $data, @query);
}

sub putpackage {
  my ($projid, $packid, @query) = @_;
  my $uri = "$BSConfig::srcserver/source/$projid/$packid/_meta";
  my $data = BSUtil::toxml({'project' => $projid, 'name' => $packid}, $BSXML::pack);
  return putdata($uri, $BSXML::pack, $data, @query);
}

# make sure projid or projid/packid exist
# returns true if projid or projid/packid already exist
sub create {
  my ($projid, $packid, @query) = @_;
  my $exists;
  # check if projid exists
  eval {
    $exists = list($projid);
  };
  if ($@) {
    die($@) unless $@ =~ /^404/;
    putproject($projid, @query);
  }
  return defined($exists) unless $packid;
  eval {
    $exists = list($projid, $packid);
  };
  if ($@) {
    die($@) unless $@ =~ /^404/;
    putpackage($projid, $packid, @query);
  }
  return defined($exists);
}

sub del {
  my ($projid, $packid, @query) = @_;
  my $uri = "$BSConfig::srcserver/source/$projid";
  $uri .= "/$packid" if $packid;
  my $param = {
    'uri' => $uri,
    'request' => 'DELETE'
  };
  return rpc($param, undef, @query);
}

sub hash2query {
  my (%opts) = @_;
  return map { "$_=$opts{$_}" } keys %opts;
}

sub commitfilelist {
  my ($projid, $packid, $entries, @query) = @_;
  my $param = {
    'uri' => "$BSConfig::srcserver/source/$projid/$packid",
    'request' => 'POST',
    'data' => BSUtil::toxml({'entry' => $entries}, $BSXML::dir),
    'headers' => [ 'Content-Type: application/octet-stream' ]
  };
  return rpc($param, $BSXML::dir, "cmd=commitfilelist", @query);
}

sub commit {
  my ($projid, $packid, $opts, %files) = @_;
  my $newcontent = delete $opts->{'newcontent'};
  my $orev = $opts->{'orev'} || 'latest';
  my $ofiles;
  $ofiles = list($projid, $packid, "rev=$orev", "expand=1") unless $newcontent;
  my @entries = @{$ofiles->{'entry'} || []};
  @entries = grep { !exists($files{$_->{'name'}}) } @entries;
  # only name and md5 attrs, please (the others don't harm, though)
  for my $e (@entries) {
    delete $e->{$_} for grep { $_ ne "name" && $_ ne "md5" } keys %$e;
  }
  delete $files{$_} for grep { !$files{$_} } keys %files;
  push @entries, {'name' => $_, 'md5' => Digest::MD5::md5_hex($files{$_})} for keys %files;
  my $todo = commitfilelist($projid, $packid, \@entries, hash2query(%$opts));
  if ($todo->{'error'}) {
    die("unexpected error: $todo->{'error'}\n") unless $todo->{'error'} eq 'missing';
    for (@{$todo->{'entry'} || []}) {
      die("origin files missing: $_->{'name'}\n") unless $files{$_->{'name'}};  # should never happen...
      putfile($projid, $packid, $_->{'name'}, $files{$_->{'name'}}, "rev=repository");
    }
    $todo = commitfilelist($projid, $packid, \@entries, hash2query(%$opts));
    die("cannot commit files: $todo->{'error'}\n") if $todo->{'error'};
  }
#  print Dumper($todo);
  return $todo;
}

sub branch {
  my ($projid, $packid, $oprojid, $opackid, %query) = @_;
  $query{'cmd'} = 'branch';
  $query{'oproject'} = $oprojid;
  $query{'opackage'} = $opackid;
  my $param = {
    'uri' => "$BSConfig::srcserver/source/$projid/$packid",
    'request' => 'POST'
  };
  return rpc($param, $BSXML::revision_acceptinfo, hash2query(%query));
}

1;
