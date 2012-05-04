# $Id: Apache2.pm 56 2012-04-30 21:17:47Z jo $
# Cindy::HTTPCore - XS a missing mod_perl2 function.
#
# Copyright (c) 2012 Joachim Zobel <jz-2008@heute-morgen.de>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

package Apache2::RequestRec;

use strict;
use warnings;

require XSLoader;
XSLoader::load('Cindy::Apache2', '0.05');


1;

