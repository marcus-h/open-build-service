#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 10;

use BSBlameTest qw(blame_is list_like create commit del branch);

create("origin", "opkg3");
# commits a file, called "testfile", to the origin/opkg3 package
commit("origin", "opkg3", {}, testfile => <<EOF);
This is a
simple text.

Section start:
Here, we will have a conflict soon.
Section end.
EOF

create("branch", "pkg3");
branch("branch", "pkg3", "origin", "opkg3");
list_like("check baserev", "branch", "pkg3", xpath => './linkinfo[@baserev = "14d20514b8eb04c5477b0a31df2a32b8"]');
# perform a blame for the branch/pkg3/testfile file:
# <prj>/<pkg>/<rev>: some content
# means that the line with "some content" was introduced in
# package <prj>/<pkg> at revision <rev>.
blame_is("directly after branch", "branch", "pkg3", "testfile", expected => <<EOF);
origin/opkg3/r1: This is a
origin/opkg3/r1: simple text.
origin/opkg3/r1: 
origin/opkg3/r1: Section start:
origin/opkg3/r1: Here, we will have a conflict soon.
origin/opkg3/r1: Section end.
EOF

commit("branch", "pkg3", {keeplink => 1}, testfile => <<EOF);
This is a
simple text.

Section start:
A line from the branch.
Section end.
EOF
blame_is("branch at r2", "branch", "pkg3", "testfile", expected => <<EOF);
origin/opkg3/r1: This is a
origin/opkg3/r1: simple text.
origin/opkg3/r1: 
origin/opkg3/r1: Section start:
branch/pkg3/r2: A line from the branch.
origin/opkg3/r1: Section end.
EOF

commit("origin", "opkg3", {}, testfile => <<EOF);
This is a
simple text.

Section start:
Here, we will have a conflict soon.
Section end.

This line does not cause a conflict.
EOF
blame_is("branch at r1 (origin changed)", "branch", "pkg3", "testfile", expected => <<EOF);
origin/opkg3/r1: This is a
origin/opkg3/r1: simple text.
origin/opkg3/r1: 
origin/opkg3/r1: Section start:
branch/pkg3/r2: A line from the branch.
origin/opkg3/r1: Section end.
origin/opkg3/r2: 
origin/opkg3/r2: This line does not cause a conflict.
EOF

commit("origin", "opkg3", {}, testfile => undef);
list_like("conflict since testfile was removed from origin", "branch", "pkg3", xpath => './linkinfo/@error');
commit("origin", "opkg3", {}, testfile => <<EOF);
This is a
simple text.

Section start:
A line from the origin.
Section end.
EOF
list_like("origin/opkg3 is at r4", "origin", "opkg3",
  xpath => '@rev = 4 and @srcmd5 = "2b4b0e8d610f44d9fb9d6b934cef4c39"');
list_like("check baserev and conflict", "branch", "pkg3",
  xpath => './linkinfo[@baserev = "14d20514b8eb04c5477b0a31df2a32b8" and @error]');

# resolve conflict in the branch
commit("branch", "pkg3", {keeplink => 1, repairlink => 1, linkrev => "2b4b0e8d610f44d9fb9d6b934cef4c39", newcontent => 1},
  testfile => <<EOF);
This is a
simple text.

Section start:
Resolved:
A line from the branch.
A line from the origin.
Section end.

This line does not cause a conflict.
EOF
list_like("check baserev and no conflict", "branch", "pkg3",
  xpath => './linkinfo[@baserev = "2b4b0e8d610f44d9fb9d6b934cef4c39" and not(@error)]');

# now the question is: which prj/pkg/rev introduced the
#   "\nThis line does not cause a conflict."
# lines? (either origin/opkg3/r2 or branch/pkg3/r3)
blame_is("branch at r3 (resolved conflict)", "branch", "pkg3", "testfile", expected => <<EOF);
origin/opkg3/r4: This is a
origin/opkg3/r4: simple text.
origin/opkg3/r4: 
origin/opkg3/r4: Section start:
branch/pkg3/r3: Resolved:
branch/pkg3/r2: A line from the branch.
origin/opkg3/r4: A line from the origin.
origin/opkg3/r4: Section end.
origin/opkg3/r2: 
origin/opkg3/r2: This line does not cause a conflict.
EOF

# alternative:
blame_is("branch at r2 (resolved conflict)", "branch", "pkg3", "testfile", expected => <<EOF);
origin/opkg3/r4: This is a
origin/opkg3/r4: simple text.
origin/opkg3/r4: 
origin/opkg3/r4: Section start:
branch/pkg3/r3: Resolved:
branch/pkg3/r2: A line from the branch.
origin/opkg3/r4: A line from the origin.
origin/opkg3/r4: Section end.
branch/pkg3/r3: 
branch/pkg3/r3: This line does not cause a conflict.
EOF

# note: it might be "confusing" that, for instance, the first four lines
# come from origin/opkg3/r4 instead of origin/opkg/r2; this is because
# testfile was readded in origin/opkg/r4 (so the references to origin/opkg/r2
# were lost), moreover, if the same parts of a file appear in the branch and
# in the origin, the "history" of the origin is taken.
