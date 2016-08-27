package BSBlame::RevisionManager;

use strict;
use warnings;

use Data::Dumper;

use BSFileDB;
use BSBlame::Revision;
use BSBlame::Range;
use BSBlame::Constraint;
use BSBlame::Iterator;

sub new {
  my ($class, $projectsdir, $srcrevlay, $getrev) = @_;
  return bless {
    'projectsdir' => $projectsdir,
    'srcrevlay' => $srcrevlay,
    'getrev' => $getrev
  }, $class;
}

# private
sub read {
  my ($self, $projid, $packid) = @_;
  my $key = "$projid/$packid";
  return $self->{'revs'}->{$key} if $self->{'revs'}->{$key};
  my $dbfn = "$self->{'projectsdir'}/$projid.pkg/$packid.rev";
  my @orevs = BSFileDB::fdb_getall($dbfn, $self->{'srcrevlay'});
  my (@revs, @ranges);
  my $i = 0;
  my $range = BSBlame::Range->new(0, \@revs);
  while (@orevs) {
    my $orev = pop @orevs;
    $orev->{'project'} = $projid;
    $orev->{'package'} = $packid;
    my $lrev = BSBlame::Revision->new($orev, $i, $self->{'getrev'});
    push @revs, $lrev;
    if (!$range->contains($lrev)) {
      $range->end($i - 1);
      push @ranges, $range;
      $range = BSBlame::Range->new($i, \@revs);
    }
    $i++;
  }
  if (@revs) {
    $range->end($i - 1);
    push @ranges, $range;
  }
  $self->{'revs'}->{$key} = \@revs;
  $self->{'ranges'}->{$key} = \@ranges;
  return \@revs;
}

sub iter {
  my ($self, $projid, $packid, @constraints) = @_;
  my $revs = $self->read($projid, $packid);
  return BSBlame::Iterator->new($revs, @constraints);
}

sub find {
  my ($self, $projid, $packid, $lsrcmd5, @constraints) = @_;
  push @constraints, BSBlame::Constraint->new("lsrcmd5 = $lsrcmd5");
  my $it = $self->iter($projid, $packid, @constraints);
  return $it->next();
}

sub range {
  my ($self, $lrev) = @_;
  my $key = $lrev->project() . '/' . $lrev->package();
  die("$key not known\n") unless $self->{'ranges'}->{$key};
  for (@{$self->{'ranges'}->{$key}}) {
    return $_ if $_->contains($lrev);
  }
  # we could print more details, but this code path shouldn't be
  # reached in the first place...
  die("unknown rev\n");
}

sub rangesplit {
  my ($self, $lrev) = @_;
  my $range = $self->range($lrev);
  my $revs = $self->read($lrev->project(), $lrev->package());
  my $oldend = $range->end($lrev->idx() - 1);
  my $newrange = BSBlame::Range->new($lrev->idx(), $revs);
  $newrange->end($oldend);
  my $key = $lrev->project() . '/' . $lrev->package();
  # we do not care about the ordering
  push @{$self->{'ranges'}->{$key}}, $newrange;
}

1;
