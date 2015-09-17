#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 1;

use BSBlameTest qw(blame_is list_like create commit del branch);

create("origin", "opkg1");
commit("origin", "opkg1", {}, testfile => <<EOF);
We start with
a very very
simple text
file.
EOF
commit("origin", "opkg1", {}, testfile => <<EOF);
We start with
a very
very
simple text
file.
EOF
blame_is("blame origin", "origin", "opkg1", "testfile", expected => <<EOF);
origin/opkg1/r1: We start with
origin/opkg1/r2: a very
origin/opkg1/r2: very
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
EOF

create("branch", "pkg1");
branch("branch", "pkg1", "origin", "opkg1");
list_like("check baserev", "branch", "pkg1", xpath => './linkinfo[@baserev = "6c23f5262aaeec2e50d46c9a630f1fd0"]');
blame_is("branch at r1", "branch", "pkg1", "testfile", expected => <<EOF);
origin/opkg1/r1: We start with
origin/opkg1/r2: a very
origin/opkg1/r2: very
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
EOF

commit("branch", "pkg1", {keeplink => 1}, testfile => <<EOF);
We start with
a very
simple text
file.

And add some
new lines in
the branch.
EOF
blame_is("branch at r2", "branch", "pkg1", "testfile", expected => <<EOF);
origin/opkg1/r1: We start with
origin/opkg1/r2: a very
origin/opkg1/r2: very
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
branch/pkg1/r2: 
branch/pkg1/r2: And add some
branch/pkg1/r2: new lines in
branch/pkg1/r2: the branch.
EOF

commit("branch", "pkg1", {keeplink => 1}, testfile => <<EOF);
We start with
a very
simple text
file.

This is a very cool line.

And add some
new lines and modify
a line in
the branch.
EOF
blame_is("branch at r3", "branch", "pkg1", "testfile", expected => <<EOF);
origin/opkg1/r1: We start with
origin/opkg1/r2: a very
origin/opkg1/r2: very
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
branch/pkg1/r2: 
branch/pkg1/r3: This is a very cool line.
branch/pkg1/r3: 
branch/pkg1/r2: And add some
branch/pkg1/r3: new lines and modify
branch/pkg1/r3: a line in
branch/pkg1/r2: the branch.
EOF

commit("origin", "opkg1", {}, testfile => <<EOF);
We start with
a very
simple text
file.

And add in the origin the next line, too.
This is a very cool line.
EOF
list_like("baserev still at r2", "branch", "pkg1", xpath => './linkinfo[@baserev = "6c23f5262aaeec2e50d46c9a630f1fd0"]');
blame_is("origin has also the cool line", "branch", "pkg1", "testfile", expected => <<EOF);
origin/opkg1/r1: We start with
origin/opkg1/r2: a very
origin/opkg1/r2: very
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
origin/opkg1/r3: 
origin/opkg1/r3: And add in the origin the next line, too.
origin/opkg1/r3: This is a very cool line.
branch/pkg1/r3: 
branch/pkg1/r2: And add some
branch/pkg1/r3: new lines and modify
branch/pkg1/r3: a line in
branch/pkg1/r2: the branch.
EOF

commit("branch", "pkg1", {keeplink => 1}, testfile => <<EOF);
Now, this file
evolved into
a not so
simple text
file.

Keep the next two lines from origin:
And add in the origin the next line, too.
This is a very cool line.

We did quite some changes in
the branch.
EOF
list_like("baserev points to r3", "branch", "pkg1", xpath => './linkinfo[@baserev = "92309cad2e5906cf2178cebe32426bae"]');
branch_is("branch at r4", "branch", "pkg1", "testfile", expected => <<EOF);
branch/pkg1/r4: Now, this file
branch/pkg1/r4: evolved into
branch/pkg1/r4: a not so
origin/opkg1/r1: simple text
origin/opkg1/r1: file.
origin/opkg1/r3: 
branch/pkg1/r4: Keep the next two lines from origin:
origin/opkg1/r3: And add in the origin the next line, too.
origin/opkg1/r3: This is a very cool line.
branch/pkg1/r3: 
branch/pkg1/r4: We die quite some changes in
branch/pkg1/r2: the branch.
EOF
