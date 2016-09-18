package BSBlame::RangeFirstStrategy;

use strict;
use warnings;

use Data::Dumper;

# XXX: remove
use BSSrcrep;

use BSBlame::Blamer;
use BSBlame::Constraint;
use BSBlame::Revision;
use BSBlame::RevisionManager;

# basically, this could be plain module with functions instead
# of a class (it's a class for reusability reasons...)

sub new {
  my ($class) = @_;
  return {}, $class;
}

sub blame {
  my ($self, $rev, $filename) = @_;
  $self->resolve($rev);
  my $mainblamer = BSBlame::Blamer->new($rev);
  my @blamers;
  my @deps = $mainblamer;
  while (@deps) {
    my $blamer = shift(@deps);
    push @blamers, $blamer;
    for my $rev (@{$blamer->deps()}) {
      push @deps, BSBlame::Blamer->new($rev);
    }
    # potential inifinite loop?
  }
  print "deps: " . @deps . "\n";
  while (@blamers) {
    print "blamers: " . @blamers . "\n";
    my @ready = grep {$_->ready($filename)} @blamers;
    print "ready: " . @ready . "\n";
    die("ready queue empty\n") unless @ready;
    for my $blamer (@ready) {
      $blamer->blame($filename);
    }
    my $ready = {map {$_ => 1} @ready};
    @blamers = grep {!$ready->{$_}} @blamers;
  }
  my $blamedata = $rev->blamedata($filename);
  print "\n###\n";
  print "file lines: " . split('\n', BSSrcrep::repreadstr($rev->intrev(), $filename, $rev->files()->{$filename})) . "\n";
  print "blame lines: " . scalar(@$blamedata) . "\n";
  my $i = 0;
  for my $rev (@$blamedata) {
    unless ($rev) {
      print "undef\n";
      next;
    }
    my $r = $rev->intrev();
    print "$r->{'project'}/$r->{'package'}/$r->{'rev'}\n";
  }
#  print $i - 1 . "\n";
}

sub resolve {
  my ($self, $rev) = @_;
  my @todo = $rev;
  while (@todo) {
    $rev = shift(@todo);
    my @deps;
    @deps = $self->resolve_expanded($rev) if $rev->isexpanded();
    @deps = $self->resolve_branch($rev) if $rev->isbranch();
    @deps = $self->resolve_plain($rev) if $rev->isplain();
#    print Dumper(\@deps);
    die("todo: plain links\n") if $rev->islink() && !$rev->isbranch();
    push @todo, @deps;
  }
}

sub resolve_expanded {
  my ($self, $rev) = @_;
  my $revmgr = $rev->revmgr();
  print "resolve expanded\n";
  my @deps;
  if ($rev->localrev()) {
    print "localrev set\n";
    push @deps, $rev->targetrev();
    push @deps, $rev->localrev() unless $rev->localrev()->resolved();
    return @deps;
  }
  my $lrev = $revmgr->find($rev->project(), $rev->package(), $rev->lsrcmd5(),
                           $rev->constraints());
  die("unable to find lrev\n") unless $lrev;
  # merge constraints and install lrev
#  print Dumper($lrev->constraints());
  $lrev->constraints($rev->constraints());
  $rev->localrev($lrev);
  $rev->resolved(1);
  push @deps, $rev->targetrev();
  push @deps, $lrev unless $lrev->resolved();
  return @deps;
}

sub resolve_branch {
  my ($self, $rev) = @_;
  my $revmgr = $rev->revmgr();
  print "resolve branch\n";
  my $lprojid = $rev->project();
  my $lpackid = $rev->package();
  my $tprojid = $rev->targetrev()->project();
  my $tpackid = $rev->targetrev()->package();
  my @deps;
  while (!$rev->resolved()) {
    # by construction of the range all local revs are branches to same target
    my $it = $revmgr->range($rev)->iter();
    my $tit = $revmgr->iter($tprojid, $tpackid);
    my $prev;
    while (my $lrev = $it->next()) {
      print $lrev->{'data'}->{'rev'}->{'rev'} . "\n";
      my @constraints = $lrev->constraints();
      push @constraints, $prev->constraints() if $prev;
      print Dumper(\@constraints);
      my ($time, $idx) = ($lrev->time(), $lrev->idx());
      push @constraints, BSBlame::Constraint->new("time <= $time");
      push @constraints, BSBlame::Constraint->new("idx > $idx",
                                                  "project = $lprojid",
                                                  "package = $lpackid");
      # XXX: lsrcmd5? if so, targetrev
      my $blsrcmd5 = $lrev->targetrev()->lsrcmd5();
      my $blrev = $tit->find(BSBlame::Constraint->new("lsrcmd5 = $blsrcmd5"),
                             @constraints);
      if (!$blrev) {
        die("unable to resolve first elm in range\n") unless $prev;
        # ok, let's hope that $lrev is really the start of a new range
        print "rangesplit\n";
        $revmgr->rangesplit($lrev);
        last;
      }
      print "base: $blrev->{'data'}->{'rev'}->{'rev'}\n";
      # install blrev and merge constraints
      # (constraints are installed to blrev _and_ the targetrev)
      $lrev->targetrev()->localrev($blrev);
      $lrev->targetrev()->constraints(@constraints);
      $lrev->resolved(1);
      push @deps, $lrev->targetrev();
      $prev = $lrev;
    }
  }
  return @deps;
}

sub resolve_plain {
  my ($self, $rev) = @_;
  my $revmgr = $rev->revmgr();
  print "resolve plain\n";
  return () if $rev->resolved();
  # hmm actually nothing todo, but let's resolve the whole range...
  my $lrev = $revmgr->find($rev->project(), $rev->package(), $rev->lsrcmd5(),
                           $rev->constraints());
  die("eek\n") unless $lrev;
  $rev->localrev($lrev);
  $rev->resolved(1);
  my $it = $revmgr->range($rev)->iter();
  while (my $lrev = $it->next()) {
    last if $lrev->resolved();
    $lrev->resolved(1);
  }
  die("logic error\n") unless $rev->resolved();
#  $rev->resolved(1);
  return ();
}

1;
