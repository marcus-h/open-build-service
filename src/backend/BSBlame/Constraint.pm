package BSBlame::Constraint;

use strict;
use warnings;

use Data::Dumper;

my $opmap = {
  '<' => sub { $_[0] + 0 < $_[1] + 0 },
  '<=' => sub { $_[0] + 0 <= $_[1] + 0 },
  '=' => sub { $_[0] eq $_[1] },
  '>=' => sub { $_[0] + 0 >= $_[1] + 0 },
  '>' => sub { $_[0] + 0 > $_[1] + 0 }
};

my $opre = join('|', map {"\Q$_\E"} keys(%$opmap));

sub new {
  my ($class, $expr) = @_;
  my $self = {};
  bless $self, $class;
  $self->parse($expr);
  return $self;
}

sub parse {
  my ($self, $expr) = @_;
  die("illegal expression: \"$expr\"\n")
    unless $expr =~ /^([^\s]+)\s*($opre)\s*(.*)/;
  $self->{'attr'} = $1;
  $self->{'op'} = $2;
  $self->{'val'} = $3;
}

sub eval {
  my ($self, $rev) = @_;
  my $meth = $rev->can($self->{'attr'});
  die("unknown attribute $self->{'attr'}\n") unless $meth;
  return $opmap->{$self->{'op'}}->($rev->$meth(), $self->{'val'});
}

sub attr {
  my ($self) = @_;
  return $self->{'attr'};
}

sub op {
  my ($self) = @_;
  return $self->{'op'};
}

sub val {
  my ($self) = @_;
  return $self->{'val'};
}

1;
