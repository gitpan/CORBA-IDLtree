#!/usr/bin/perl
#
# idl2ada.pl:       IDL symbol tree to Ada95 translator
# Version:          0.8b
# Supported CORBA systems:
#                   * ORBit (ftp://ftp.gnome.org/pub/ORBit/)
#                   * CORBAware (http://www.atm-computer.de)
#          NOT YET: * TAO (http://www.cs.wustl.edu/~schmidt/TAO.html)
#                     Uses GNAT specific C++ interfacing pragmas; currently
#                     client side only due to problem with GNAT 3.11p C++
#                     interfacing
# Requires:         Perl5 module CORBA::IDLtree
# Author/Copyright: Oliver M. Kellogg (gnack@adapower.com)
#
# This file is part of GNACK, the GNU Ada CORBA Kit.
#
# GNACK is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# GNACK is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#

use CORBA::IDLtree;

# Subroutine forward declarations

sub print_help;
sub gen_ada;
sub gen_helper_ops;
sub gen_typecode_and_anycnv;
sub mapped_type;
sub isnode;       # shorthand for CORBA::IDLtree::isnode
sub is_a;
sub is_a_string;
sub is_complex;   # returns 0 if representation of struct is same in C and Ada
sub is_variable;
sub pass_by_reference;
sub return_by_reference;
sub is_objref;
sub needs_IDL_FILE;  # Ugly capitals.. for the sake of conciseness
sub dupproc;
sub freeproc;
sub ada_from_c_var;
sub c_from_ada_var;
sub c2ada;
sub ada2c;
sub check_features_used;
sub search_enum_type;
sub search_enum_literal;
sub open_files;
sub specfilename;
sub bodyfilename;
# Emit subroutines
sub epspec;     # emit to proxy spec
sub epbody;     # emit to proxy body
sub epboth;     # emit to both proxy spec and proxy body
sub eispec;     # emit to impl spec
sub eibody;     # emit to impl body
sub eiboth;     # emit to both impl spec and body
sub eospec;     # emit to POA spec
sub eobody;     # emit to POA body
sub eoboth;     # emit to both POA spec and body
sub ehspec;     # emit to helper spec
sub ehbody;     # emit to helper body
sub ehboth;     # emit to both helper spec and body
sub epispec;    # emit to proxy and impl spec
sub epibody;    # emit to proxy and impl body
sub epospec;    # emit to proxy and POA spec
sub epobody;    # emit to proxy and POA body
sub eall;       # emit to all files except the POA body
# Print subroutines (print is same as emit, but with indentation)
sub ppspec;     # print to proxy spec
sub ppbody;     # print to proxy body
sub ppboth;     # print to both proxy spec and proxy body
sub pispec;     # print to impl spec
sub pibody;     # print to impl body
sub piboth;     # print to both impl spec and body
sub pospec;     # print to POA spec
sub pobody;     # print to POA body
sub poboth;     # print to both POA spec and body
sub phspec;     # print to helper spec
sub phbody;     # print to helper body
sub phboth;     # print to both helper spec and body
sub ppispec;    # print to proxy and impl spec
sub ppibody;    # print to proxy and impl body
sub ppospec;    # print to proxy and POA spec
sub ppobody;    # print to proxy and POA body
sub pall;       # print to all files except the POA body
sub pospecbuf;  # print to $poaspecbuf
sub print_withlist;
sub print_pkg_decl;
sub finish_pkg_decl;
sub print_spec_interface_fixedparts;
sub print_body_interface_fixedparts;
sub print_ispec_interface_fixedparts;
sub print_ibody_interface_fixedparts;


# Constants

# possible target systems
$ORBIT     = 0;
$CORBAWARE = 1;
$TAO       = 2;
# File naming convention used
$GNAT      = 0;   # spec ends in .ads, body in .adb
$APEX      = 1;   # spec ends in .1.ada, body in .2.ada
# C++ compiler used (in case of C++ ORB; default is GNU C++)
# Note: Presently, GNAT only supports interfacing with GNU C++
$GPP       = 0;
$DECCXX    = 1;
# shorthands for frequently used constants from CORBA::IDLtree
$NAME = $CORBA::IDLtree::NAME;
$TYPE = $CORBA::IDLtree::TYPE;
$SUBORDINATES = $CORBA::IDLtree::SUBORDINATES;
$MODE = $SUBORDINATES;
$SCOPEREF = $CORBA::IDLtree::SCOPEREF;
$GEN_C_TYPE = $CORBA::IDLtree::LANG_C;
$DONT_ANALYZE_ARRAY = 1;    # optional arg to sub is_complex
$ANALYZE_UNION = 2;         # optional arg to sub is_complex
# number of spaces for one indentation
$INDENT = 3;
# number of indents for an approx. 1/3-page (25 space) indentation
$INDENT2 = (1 << (5 - $INDENT)) + 4;
# file handles
@proxy_spec_file_handle = qw/ PS0 PS1 PS2 PS3 PS4 PS5 PS6 PS7 PS8 PS9 /;
@proxy_body_file_handle = qw/ PB0 PB1 PB2 PB3 PB4 PB5 PB6 PB7 PB8 PB9 /;
@impl_spec_file_handle  = qw/ IS0 IS1 IS2 IS3 IS4 IS5 IS6 IS7 IS8 IS9 /;
@impl_body_file_handle  = qw/ IB0 IB1 IB2 IB3 IB4 IB5 IB6 IB7 IB8 IB9 /;
@poa_spec_file_handle   = qw/ OA0 OA1 OA2 OA3 OA4 OA5 OA6 OA7 OA8 OA9 /;
@poa_body_file_handle   = qw/ OB0 OB1 OB2 OB3 OB4 OB5 OB6 OB7 OB8 OB9 /;
@hlp_spec_file_handle   = qw/ HS0 HS1 HS2 HS3 HS4 HS5 HS6 HS7 HS8 HS9 /;
@hlp_body_file_handle   = qw/ HB0 HB1 HB2 HB3 HB4 HB5 HB6 HB7 HB8 HB9 /;
    # The file handles are indexed by $#scopestack.

# Global variables
$target_system = $ORBIT;
$file_convention = $GNAT;
$cplusplus = $GPP;   # C++ compiler used
$arch = 32;          # machine architecture (32 or 64 bit)
$dump_idl = 0;       # Regenerate IDL from the parse tree (dump to stdout)
$gen_tc_any = 0;     # Generate TypeCode and functions From_Any/To_Any
$dont_gen_impl = 0;  # Do not generate POA and Impl files
$gen_separates = 0;  # Generate Impl method body skeletons as `separate'
@gen_ispec = ();     # Generate implementation package spec (see gen_ada)
@gen_ibody = ();     # Generate implementation package body (see gen_ada)
@indentlvl = ();     # Stack of indentation levels
@scopestack = ();    # Stack of module/interface names
@withlist = ();      # List of user packages to "with"
%ancestors = ();     # Ancestor interface names (at interface inheritance)
%fwd_decl = ();      # References to possible INTERFACE_FWD node;
                     # indexed by interface name
%helpers = ();       # Names that have helper packages
%strbound = ();      # Bound numbers of bounded strings
%wstrbound = ();     # Bound numbers of bounded wide strings
@opened_helper = (); # Stack of flags; moves in parallel with @scopestack;
                     # true when helper file has been opened
$specbuf = "";       # Proxy spec file output buffer (not yet used)
$poaspecbuf = "";    # POA spec file output buffer
$poaspecbuf_enabled = 0;     # enable(disable=0) output to POA spec buffer
$did_file_prologues = 0;     # Flag; true when prologues were already written
$global_scope_pkgname = "";  # only set if _IDL_File synthesis required
$global_idlfile = "";        # name of IDL file currently processed
$global_symroot = 0;         # return value of CORBA::IDLtree::Parse_File
$pragprefix = "";    # the name given in a #pragma prefix, suffixed with '/'
$cpp_cmdline = "";   # arguments passed to the C preprocessor
$psfh = 0;           # Shorthand for $proxy_spec_file_handle[$#scopestack]
$pbfh = 0;           # Shorthand for $proxy_body_file_handle[$#scopestack]
$isfh = 0;           # Shorthand for $impl_spec_file_handle[$#scopestack]
$ibfh = 0;           # Shorthand for $impl_body_file_handle[$#scopestack]
$osfh = 0;           # Shorthand for $poa_spec_file_handle[$#scopestack]
$obfh = 0;           # Shorthand for $poa_body_file_handle[$#scopestack]
$hsfh = 0;           # Shorthand for $hlp_spec_file_handle[$#scopestack]
$hbfh = 0;           # Shorthand for $hlp_body_file_handle[$#scopestack]
$gsearch_symbol = "";   # auxiliary variable for sub search_enum_literal
$gsearch_result = 0;    # auxiliary variable for sub search_enum_literal
# feature flags
# TO BE REFINED! These should be on a per-interface basis
$need_unbounded_seq = 0;
$need_bounded_seq = 0;
$need_exceptions = 0;

# MAIN PROGRAM

# Options processing
$verbose = 0;
if ($#ARGV < 0) {
    print_help;
    exit 0;
}

for ($i=0; $i <= $#ARGV; $i++) {
    if ($ARGV[$i] =~ /^-/) {
        for (substr($ARGV[$i], 1)) {
            /^orbit$/i     and $target_system = $ORBIT, last;
            /^cw$/i        and $target_system = $CORBAWARE, last;
            /^tao$/i       and $target_system = $TAO, last;
            /^gpp$/i       and $cplusplus = $GPP, last;
            /^deccxx$/i    and $cplusplus = $DECCXX, last;
            /^h/           and print_help, last;
            /^d$/          and $dump_idl = 1, last;
            /^v$/          and $verbose = 1, last;
            /^s$/          and $gen_separates = 1, last;
            /^I/           and $cpp_cmdline .= ' ' . $ARGV[$i], last;
            /^D/           and $cpp_cmdline .= ' ' . $ARGV[$i], last;
            /^S$/          and $dont_gen_impl = 1, last;
            /^T$/          and $gen_tc_any = 1, last;
            /^U/           and $cpp_cmdline .= ' ' . $ARGV[$i], last;
            /^X$/          and $file_convention = $APEX, last;
            /^Yp,/         and last;
            /^Wb,/         and last;
            /^V$/          and print("idl2ada.pl version 0.8b\n"), last;
            die "unknown option: $ARGV[$i]\n";
        }
        splice(@ARGV, $i--, 1);
    }
}

# Determine machine architecture (32 bit or 64 bit, this is needed
# by sub mangled_name for TAO interfacing)
my $uname = `uname -a`;
if ($uname =~ /21[0-9]64/) {
    $arch = 64;
} else {
    $arch = 32;
}

# Generate Ada

while (@ARGV) {
    $global_idlfile = shift @ARGV;
    $global_symroot = CORBA::IDLtree::Parse_File($global_idlfile, $cpp_cmdline);
    die "errors while parsing $global_idlfile\n" unless ($global_symroot);
    CORBA::IDLtree::Dump_Symbols($global_symroot) if ($dump_idl);
    # Determine whether a global-scope _IDL_FILE needs to be generated
    $global_scope_pkgname = "";
    foreach $decl (@{$global_symroot}) {
        if (needs_IDL_FILE $decl) {
            $global_scope_pkgname = $global_idlfile;
            $global_scope_pkgname =~ s/\.idl$//;
            $global_scope_pkgname =~ s/\W/_/g;
            $global_scope_pkgname .= "_IDL_File";
            last;
        }
    }

    @withlist = ();
    CORBA::IDLtree::traverse_tree($global_symroot, \&check_features_used, 1);
    if (isnode $global_symroot) {
        my $type = ${$global_symroot}[$TYPE];
        my $name = ${$global_symroot}[$NAME];
        if ($type != $CORBA::IDLtree::MODULE and
            $type != $CORBA::IDLtree::INTERFACE) {
            print "$name: expecting MODULE or INTERFACE\n";
            return;
        }
        $did_file_prologues = 0;
        gen_ada $global_symroot;
        next;
    } elsif (not ref $global_symroot) {
        die "\nunsupported declaration $global_symroot\n";
    }

    my $global_scope_file_is_open = 0;
    foreach $noderef (@{$global_symroot}) {
        my $type = ${$noderef}[$TYPE];
        my $name = ${$noderef}[$NAME];
        my $suboref = ${$noderef}[$SUBORDINATES];
        $did_file_prologues = 0;
        $poaspecbuf = "private\n\n";

        if ($type == $CORBA::IDLtree::MODULE or
            $type == $CORBA::IDLtree::INTERFACE) {
            if ($global_scope_file_is_open) {
                finish_pkg_decl $global_scope_pkgname;
                $global_scope_file_is_open = 0;
            }
            gen_ada $noderef;

        } elsif ($type == $CORBA::IDLtree::INCFILE) {
            foreach $incnode (@{$suboref}) {
                if (! isnode($incnode) ||
                    ($$incnode[$TYPE] != $CORBA::IDLtree::INCFILE &&
                     $$incnode[$TYPE] != $CORBA::IDLtree::PRAGMA_PREFIX &&
                     $$incnode[$TYPE] != $CORBA::IDLtree::MODULE &&
                     $$incnode[$TYPE] != $CORBA::IDLtree::INTERFACE)) {
                    print("idl2ada restriction: cannot handle global-scope " .
                          "declaration in $name\n");
                } elsif ($$incnode[$TYPE] != $CORBA::IDLtree::PRAGMA_PREFIX) {
                    my $name = $$incnode[$NAME];
                    $name =~ s/\.idl//i;
                    $name =~ s@.*/@@;
                    push @withlist, $name;
                }
            }

        } elsif ($type == $CORBA::IDLtree::PRAGMA_PREFIX) {
            $pragprefix = $name . '/';

        } else {
            if (! $global_scope_file_is_open) {
                open_files($global_scope_pkgname, $CORBA::IDLtree::MODULE);
                print_withlist $global_scope_pkgname;
                print_pkg_decl $global_scope_pkgname;
                $global_scope_file_is_open = 1;
            }
            gen_ada $noderef;
        }
    }
    if ($global_scope_file_is_open) {
        finish_pkg_decl $global_scope_pkgname;
    }
}

# END OF MAIN PROGRAM


# Ada back end subroutines

sub print_help {
    print "Available options:\n";
    print "-orbit        generate code for ORBit (default)\n";
    print "-cw           generate code for CORBAware\n";
    print "-tao          generate code for TAO (not yet fully implemented)\n";
    print "-gpp          generate interfacing to GNU C++ (TAO default)\n";
    print "-deccxx       generate interfacing to DEC C++ (TAO NYI)\n";
    print "-h            print this help message and exit\n";
    print "-v            verbose mode\n";
    print "-d            re-create IDL from internal parse tree (to stdout)\n";
    print "-T            generate TypeCodes and From_Any/To_Any methods\n";
    print "-s            generate \"is separate\" declarations in Impl body\n";
    print "-S            suppress generation of Impl package\n";
    print "-I<path>      include file search path for preprocessor\n";
    print "-D<sym>[=val] define symbol for preprocessor\n";
    print "-U<sym>       undefine symbol for preprocessor\n";
    print "-X            generate Rational Apex file names (default: GNAT)\n";
    print "-V            print version information\n";
    print "\n";
}


sub epspec {
    my $text = shift;
    print $psfh $text;
}

sub epbody {
    my $text = shift;
    print $pbfh $text;
}

sub epboth {
    my $text = shift;
    epspec $text;
    epbody $text;
}

sub eispec {
    my $text = shift;
    if ($gen_ispec[$#scopestack]) {
        print $isfh $text;
    }
}

sub eibody {
    my $text = shift;
    if ($gen_ibody[$#scopestack]) {
        print $ibfh $text;
    }
}

sub eiboth {
    my $text = shift;
    eispec $text;
    eibody $text;
}

sub eospec {
    my $text = shift;
    unless ($dont_gen_impl) {
        print $osfh $text;
    }
}

sub especbuf {
    $specbuf .= shift;
}

sub eospecbuf {
    $poaspecbuf .= shift;
}

sub eobody {
    my $text = shift;
    unless ($dont_gen_impl) {
        print $obfh $text;
        if ($poaspecbuf_enabled > 1) {   # Beware: output might also go to the
            eospecbuf $text;             # POA spec buffer
        }
    }
}

sub eoboth {
    my $text = shift;
    eospec $text;
    eobody $text;
}

sub epispec {
    my $text = shift;
    epspec $text;
    eispec $text;
}

sub epibody {
    my $text = shift;
    epbody $text;
    eibody $text;
}

sub epospec {
    my $text = shift;
    epspec $text;
    if ($poaspecbuf_enabled) {
        eospecbuf $text;
    } else {
        eospec $text;
    }
}

sub epobody {
    my $text = shift;
    epbody $text;
    eobody $text;
}

sub eall {
    my $text = shift;
    epispec $text;
    epibody $text;
    eospec $text;
    if ($poaspecbuf_enabled > 1) {   # Beware: output might also go to the
        eospecbuf $text;             # POA spec buffer
    }
}

sub ehspec {
    my $text = shift;
    print $hsfh $text;
}

sub ehbody {
    my $text = shift;
    print $hbfh $text;
}

sub ehboth {
    my $text = shift;
    ehspec $text;
    ehbody $text;
}


sub ppspec {
    my $text = (' ' x ($INDENT * $indentlvl[$#indentlvl])) . shift;
    epspec $text;
}

sub ppbody {
    my $text = shift;
    my $ilvl = $indentlvl[$#indentlvl] + ($poaspecbuf_enabled == 2);
    epbody((' ' x ($INDENT * $ilvl)) . $text);
}

sub ppboth {
    my $text = shift;
    ppspec $text;
    ppbody $text;
}

sub pispec {
    my $text = (' ' x ($INDENT * $indentlvl[$#indentlvl])) . shift;
    eispec $text;
}

sub pibody {
    my $text = (' ' x ($INDENT * $indentlvl[$#indentlvl])) . shift;
    eibody $text;
}

sub piboth {
    my $text = shift;
    pispec $text;
    pibody $text;
}

sub pospec {
    my $text = (' ' x ($INDENT * $indentlvl[$#indentlvl])) . shift;
    eospec $text;
}

sub pobody {
    my $text = (' ' x ($INDENT * $indentlvl[$#indentlvl])) . shift;
    eobody $text;
}

sub poboth {
    my $text = shift;
    if (! $poaspecbuf_enabled) {
        pospec $text;
    }
    pobody $text;
}

sub phspec {
    my $text = (' ' x ($INDENT * $indentlvl[$#indentlvl])) . shift;
    ehspec $text;
}

sub phbody {
    my $text = (' ' x ($INDENT * $indentlvl[$#indentlvl])) . shift;
    ehbody $text;
}

sub phboth {
    my $text = shift;
    phspec $text;
    phbody $text;
}

sub ppispec {
    my $text = shift;
    ppspec $text;
    pispec $text;
}

sub ppibody {
    my $text = shift;
    ppbody $text;
    pibody $text;
}

sub ppospec {
    my $text = shift;
    ppspec $text;
    pospec $text;
}

sub pspecbuf {
    my $text = (' ' x ($INDENT * $indentlvl[$#indentlvl])) . shift;
    especbuf $text;
}

sub pospecbuf {
    my $text = (' ' x ($INDENT * $indentlvl[$#indentlvl])) . shift;
    eospecbuf $text;
}

sub ppobody {
    my $text = shift;
    ppbody $text;
    pobody $text;
}

sub pall {
    my $text = shift;
    ppispec $text;
    ppibody $text;
    pospec $text;
    if ($poaspecbuf_enabled > 1) {   # Beware: output might also go to the
        pospecbuf $text;             # POA spec buffer
    }
}


sub specfilename {
    my $filename;
    if ($file_convention == $GNAT) {
        $filename = join('-', @_) . ".ads";
    } elsif ($file_convention == $APEX) {
        $filename = join('.', @_) . ".1.ada";
    } else {
        die "specfilename: internal error - unimplemented naming convention\n";
    }
    lc $filename;
}

sub bodyfilename {
    my $filename;
    if ($file_convention == $GNAT) {
        $filename = join('-', @_) . ".adb";
    } elsif ($file_convention == $APEX) {
        $filename = join('.', @_) . ".2.ada";
    } else {
        die "bodyfilename: internal error - unimplemented naming convention\n";
    }
    lc $filename;
}

$overwrite_warning =
      "----------------------------------------------------------------\n"
    . "-- WARNING:  This is generated Ada source that is automatically\n"
    . "--           overwritten when idl2ada.pl is run.\n"
    . "--           Changes to this file will be lost.\n"
    . "----------------------------------------------------------------\n\n";

sub print_specfile_prologue {
    my $pkgname = shift;
    ppspec $overwrite_warning;
    if ($need_exceptions) {
        ppspec "with Ada.Exceptions;\n";
    }
    ppspec "with CORBA, CORBA.Object;\n";
    ppspec "use type CORBA.Short, CORBA.Long;\n";
    ppspec "use type CORBA.Unsigned_Short, CORBA.Unsigned_Long;\n";
    if ($need_unbounded_seq) {
        ppspec "with CORBA.Sequences.Unbounded;\n";
    }
    if ($need_bounded_seq) {
        ppspec "with CORBA.Sequences.Bounded;\n";
    }
    # ppspec "with CORBA.InterfaceDef;\n";
    # ppspec "with CORBA.ImplementationDef;\n";
    foreach $bound (keys %strbound) {
        ppspec "with CORBA.Bounded_String_$bound;\n";
    }
    foreach $bound (keys %wstrbound) {
        ppspec "with CORBA.Bounded_Wide_String_$bound;\n";
    }
    # foreach $hlppkg (keys %helpers) {
    #     if ($hlppkg !~ /$pkgname/i) {
    #         ppspec "with $hlppkg.Helper;\n";
    #     }
    # }
    epspec "\n";
}

sub print_bodyfile_prologue {
    my $pkgname = shift;
    ppbody $overwrite_warning;
    ppbody "with System;\n";
    if ($need_exceptions or $gen_tc_any) {
        ppbody("with Unchecked_Conversion;\n") if ($gen_tc_any);
        ppbody "with System.Address_To_Access_Conversions;\n";
    }
    ppbody "with C_Strings;\n";
    ppbody "with CORBA.Environment, CORBA.C_Types;\n";
    if ($target_system == $CORBAWARE) {
        ppbody "with CORBA.Basic_Object;\n";
    }
    foreach $hlppkg (keys %helpers) {
        ppbody "with $hlppkg.Helper;\n";
    }
    epbody "\n";
}

sub print_ospecfile_prologue {
    my $pkgname = shift;
    pospec $overwrite_warning;
    pospec "with System, C_Strings;\n";
    pospec "with CORBA, CORBA.Object, CORBA.C_Types, CORBA.Environment;\n";
    if ($target_system == $CORBAWARE) {
        pospec "with CORBA.Basic_Object;\n";
    } else {
        pospec "with PortableServer;\n";
    }
    pospec "with $pkgname;\n";
    pospec "use  $pkgname;\n\n";
}

sub print_obodyfile_prologue {
    my $pkgname = shift;
    pobody $overwrite_warning;
    pobody "with System;\n";
    if ($need_exceptions) {
        pobody "with System.Address_To_Access_Conversions;\n";
        pobody "with Ada.Exceptions;\n";
    }
    if ($target_system == $CORBAWARE) {
        pobody "with Unchecked_Conversion;\n";
        pobody "with CORBA.BOA;\n";
    } else {
        pobody "with PortableServer.Servant_Base_Map;\n";
    }
    foreach $bound (keys %strbound) {
        pobody "with CORBA.Bounded_String_$bound;\n";
    }
    foreach $bound (keys %wstrbound) {
        pobody "with CORBA.Bounded_Wide_String_$bound;\n";
    }
    pobody "\n";
}

sub print_ispecfile_prologue {
    my $pkgname = shift;
    pispec "----------------------------------------------------------------\n";
    pispec "-- $pkgname.Impl (spec)\n";
    pispec "--\n";
    pispec "-- This file will not be overwritten by idl2ada.pl\n";
    pispec "----------------------------------------------------------------\n";
    pispec "\n";
    if ($target_system == $CORBAWARE) {
        pispec "with CORBA.InterfaceDef, CORBA.ImplementationDef;\n";
    }
    pispec "with POA_$pkgname;\n\n";
}

sub print_ibodyfile_prologue {
    my $pkgname = shift;
    pibody "----------------------------------------------------------------\n";
    pibody "-- $pkgname.Impl (body)\n";
    pibody "--\n";
    pibody "-- This file will not be overwritten by idl2ada.pl\n";
    pibody "----------------------------------------------------------------\n";
    if ($target_system == $CORBAWARE) {
        pibody "\nwith System, Unchecked_Conversion;\n";
    }
    pibody "\n";
}


sub print_withlist {
    my $root_pkg = shift;
    # $root_pkg =~ s/\..*//;
    my $is_module = 0;
    if (@_) {
        $is_module = shift;
    }
    if (@withlist) {
        foreach $w (@withlist) {
            if (exists $helpers{lc $w}) {
                epbody("with $w.Helper;\n") unless ($is_module);
                eospec "with $w.Helper;\n";
                if (exists $helpers{lc $root_pkg} and $w ne $root_pkg) {
                    ehspec "with $w.Helper;\n";
                }
            }
            next if ($w eq $root_pkg);
            epispec "with $w;\n";
            eospec "with $w;\n";
        }
        eispec "\n";
        epospec "\n";
    }
    if (%ancestors) {
        foreach $a (keys %ancestors) {
            next if ($a eq $root_pkg);
            eospec "with POA_$a, $a.Impl;\n";
        }
        eospec "\n";
    }
}


sub print_pkg_decl {
    my $name = shift;
    my $is_interface = 0;
    if (@_) {
        $is_interface = shift;
    }
    epspec "package $name is\n\n";
    epbody "package body $name is\n\n";
    if ($is_interface) {
        eospec "package POA_$name is\n\n";
        eobody "package body POA_$name is\n\n";
        if ($gen_ispec[$#scopestack]) {
            eispec "package $name.Impl is\n\n";
        }
        if ($gen_ibody[$#scopestack]) {
            eibody "package body $name.Impl is\n\n";
        }
    }
    $indentlvl[$#indentlvl]++;
}

sub finish_pkg_decl {
    my $name = shift;
    my $is_interface = 0;
    if (@_) {
        $is_interface = shift;
    }
    $indentlvl[$#indentlvl]--;
    ppspec "end $name;\n\n";
    close $psfh;
    ppbody "end $name;\n\n";
    close $pbfh;
    if ($opened_helper[$#scopestack]) {
        ehboth "end $name.Helper;\n\n";
        close $hsfh;
        close $hbfh;
    }
    unless ($is_interface) {
        pop @opened_helper;
        pop @scopestack;
        return;
    }
    eoboth "end POA_$name;\n\n";
    close $osfh;
    close $obfh;
    pop @indentlvl;
    if ($gen_ispec[$#scopestack]) {
        eispec "end $name.Impl;\n\n";
        close $isfh;
    }
    if ($gen_ibody[$#scopestack]) {
        eibody "end $name.Impl;\n\n";
        close $ibfh;
    }
    pop @opened_helper;
    pop @scopestack;
    if (@scopestack) {
        $psfh = $proxy_spec_file_handle[$#scopestack];
        $pbfh = $proxy_body_file_handle[$#scopestack];
        $osfh = $poa_spec_file_handle[$#scopestack];
        $obfh = $poa_body_file_handle[$#scopestack];
        if ($gen_ispec[$#scopestack]) {
            $isfh = $impl_spec_file_handle[$#scopestack];
        }
        if ($gen_ibody[$#scopestack]) {
            $ibfh = $impl_body_file_handle[$#scopestack];
        }
        if ($opened_helper[$#scopestack]) {
            $hsfh = $hlp_spec_file_handle[$#scopestack];
            $hbfh = $hlp_body_file_handle[$#scopestack];
        }
    }
}


sub print_spec_interface_fixedparts {
    my $iface = shift;
    my $ancestor = shift;
    ppspec "type Ref is new ";
    pospec "type Object is abstract new ";
    if (@{$ancestor}) {   # multi-inheritance TBD
        my $first_ancestor = $$ancestor[0];
        my $faname = ${$first_ancestor}[$NAME];
        epspec "$faname.Ref";
        eospec "$faname.Impl.Object";
    } else {
        epspec "CORBA.Object.Ref";
        if ($target_system == $CORBAWARE) {
            eospec "CORBA.Basic_Object.Object";
        } else {
            eospec "PortableServer.Servant_Base";
        }
    }
    eospec " with null record;\n";
    pospec "type Object_Access is access all Object'Class;\n\n";
    if ($target_system != $CORBAWARE) {
        pospec "procedure Init (Self : Object_Access;\n";
        pospec "                Called_From_Derived_Class : Boolean := False);";
        eospec "\n\n";
    }
    epspec " with null record;\n\n";
    $iface =~ s/\./::/g;
    ppspec "Typename : constant CORBA.String\n";
    ppspec "         := CORBA.To_CORBA_String (\"$iface\");\n\n";
    ppspec "-- Narrow/Widen functions\n";
    ppspec "--\n";
    ppspec "function Unchecked_To_Ref (From: in CORBA.Object.Ref'Class)";
    epspec " return Ref;\n";
    ppspec "function To_Ref (From: in CORBA.Object.Ref'Class) return Ref\n";
    ppspec "         renames Unchecked_To_Ref;  -- preliminary impl.\n\n";
    ppspec "\n";
}

sub print_body_interface_fixedparts {
    my $iface = shift;
    my $ancestor = shift;
    ppbody "function Unchecked_To_Ref (From: in CORBA.Object.Ref'Class)";
    epbody " return Ref is\n";
    ppbody "   Result : Ref;\n";
    ppbody("   C_Ref : System.Address := " . get_c_ref("From") . ";\n");
    if ($target_system == $CORBAWARE) {
        ppbody "   C_Env : Corba.Environment.Object :=";
        epbody " CORBA.Basic_Object.Get_C_Env (From);\n";
    }
    ppbody "begin\n";
    $indentlvl[$#indentlvl]++;
    ppbody set_c_ref("Result", "C_Ref");
    if ($target_system == $CORBAWARE) {
        ppbody "CORBA.Basic_Object.Set_C_Env (Result, C_Env);\n";
    }
    ppbody "return Result;\n";
    $indentlvl[$#indentlvl]--;
    ppbody "end Unchecked_To_Ref;\n";
    ppbody "\n\n";
    # POA body
    if ($target_system == $CORBAWARE) {
       pobody "function To_Pointer is new Unchecked_Conversion";
       eobody " (System.Address, Object_Access);\n\n";
       return;
    }
    pobody "package C_Map is new PortableServer.Servant_Base_Map\n";
    $indentlvl[$#indentlvl] += $INDENT2;
    pobody "(Object, Object_Access);\n";
    $indentlvl[$#indentlvl] -= $INDENT2;
    pobody "\n";
    pobody "procedure Init (Self : Object_Access;\n";
    pobody "                Called_From_Derived_Class : Boolean := False) is\n";
    $indentlvl[$#indentlvl]++;
    pobody "procedure C_Init (Servant : PortableServer.C_Servant_Access;\n";
    pobody "                  Env : access CORBA.Environment.Object);\n";
    $iface =~ s/\./_/g;
    pobody "pragma Import (C, C_Init, \"POA_$iface\__init\");\n";
    pobody "C_Servant : PortableServer.C_Servant_Access;\n";
    pobody "Env : aliased CORBA.Environment.Object;\n";
    $indentlvl[$#indentlvl]--;
    pobody "begin\n";
    $indentlvl[$#indentlvl]++;
    pobody "if not Called_From_Derived_Class then\n";
    $indentlvl[$#indentlvl]++;
    pobody "C_Servant := new PortableServer.C_Servant_Struct;\n";
    pobody "C_Servant.all := (ORB_Data => System.Null_Address,\n";
    pobody "                  VEPV_Address => vepv'address);\n";
    pobody "C_Init (C_Servant, Env'access);\n";
    pobody "PortableServer.Set_C_Servant (Self, C_Servant);\n";
    $indentlvl[$#indentlvl]--;
    pobody "end if;\n";
    if (@{$ancestor}) {   # multi-inheritance TBD
        my $first_ancestor = $$ancestor[0];
        my $faname = ${$first_ancestor}[$NAME];
        pobody "POA_$faname.Init (POA_$faname.Object_Access (Self),\n";
        pobody "                   Called_From_Derived_Class => True);\n";
    }
    pobody "C_Map.Insert (Self);\n";
    $indentlvl[$#indentlvl]--;
    pobody "end Init;\n\n";
}

sub print_ispec_interface_fixedparts {
    my $iface = shift;
    my $ancestor = 0;
    if (@_) {
        $ancestor = shift;
    }
    pispec "type Object is new POA_$iface.Object with private;\n\n";
    if ($target_system == $CORBAWARE) {
        pispec "-- CORBAware specific functions\n";
        pispec "function To_Ref (From: in Object) return Ref;\n";
        pispec "function Get_Interface return CORBA.InterfaceDef.Ref;\n";
        pispec "function Get_Implementation return ";
        eispec " CORBA.ImplementationDef.Ref;\n\n";
    }
}

sub print_ibody_interface_fixedparts {
    my $ifc = shift;
    if ($target_system == $CORBAWARE) {
        pibody "-- CORBAware specific functions\n";
        pibody "function To_Ref (From: in Object) return Ref is\n";
        pibody "   function Coerce is new Unchecked_Conversion (Object, Ref);\n";
        pibody "begin\n";
        pibody "   return Coerce (From);\n";
        pibody "end To_Ref;\n\n";
        pibody "function Get_Interface return CORBA.InterfaceDef.Ref is\n";
        pibody "   procedure $ifc\_Dispatcher (Attr: System.Address;";
        eibody " Buf: System.Address);\n";
        pibody "   pragma Import (C, $ifc\_Dispatcher, \"$ifc\_Dispatcher\");\n";
        pibody "   Result: CORBA.InterfaceDef.Ref;\n";
        pibody "begin\n";
        pibody "   CORBA.InterfaceDef.Set_C_Ref (Result,";
        eibody " $ifc\_Dispatcher'Address);\n";
        pibody "   return Result;\n";
        pibody "end Get_Interface;\n\n";
        pibody "function Get_Implementation return ";
        eibody " CORBA.ImplementationDef.Ref is\n";
        pibody "   Result : CORBA.ImplementationDef.Ref;\n";
        pibody "begin\n";
        pibody "   CORBA.ImplementationDef.Set_C_Ref";
        eibody " (Result, System.Null_Address);\n";
        pibody "   return Result;\n";
        pibody "end Get_Implementation;\n";
        pibody "-- end of CORBAware specific functions\n\n";
    }
}


sub open_files {
    my $name = shift;
    my $type = shift;
    push @scopestack, $name;
    push @opened_helper, 0;
    my $basename = lc(join "-", @scopestack);
    my $specfile = specfilename($basename);
    my $bodyfile = bodyfilename($basename);
    $psfh = $proxy_spec_file_handle[$#scopestack];
    $pbfh = $proxy_body_file_handle[$#scopestack];
    open($psfh, ">$specfile") or die "cannot create file $specfile\n";
    if ($type == $CORBA::IDLtree::INTERFACE) {
        open($pbfh, ">$bodyfile") or die "cannot create file $bodyfile\n";
        my $ispecfile = specfilename($basename, "impl");
        my $ibodyfile = bodyfilename($basename, "impl");
        my $poaspecfile = "poa_" . $specfile;
        my $poabodyfile = "poa_" . $bodyfile;
        if ($dont_gen_impl or -e $ispecfile) {
            $gen_ispec[$#scopestack] = 0;
        } else {
            $isfh = $impl_spec_file_handle[$#scopestack];
            open($isfh, ">$ispecfile") or die "cannot create $ispecfile\n";
            $gen_ispec[$#scopestack] = 1;
        }
        if ($dont_gen_impl or -e $ibodyfile) {
            if ($gen_ispec[$#scopestack]) {
                print "$ispecfile does not exist, but $ibodyfile does\n";
                print "         => generating only $ispecfile\n";
            } elsif ($verbose) {
                print "not generating $basename implementation files ";
                print "because they already exist\n";
            }
            $gen_ibody[$#scopestack] = 0;
        } else {
            $ibfh = $impl_body_file_handle[$#scopestack];
            open($ibfh, ">$ibodyfile") or die "cannot create $ibodyfile\n";
            if (! $gen_ispec[$#scopestack]) {
                print "$ispecfile does exist, but $ibodyfile does not\n";
                print "         => generating only $ibodyfile\n";
            }
            $gen_ibody[$#scopestack] = 1;
        }
        unless ($dont_gen_impl) {
            $osfh = $poa_spec_file_handle[$#scopestack];
            open($osfh, ">$poaspecfile") or die "cannot create $poaspecfile\n";
            $obfh = $poa_body_file_handle[$#scopestack];
            open($obfh, ">$poabodyfile") or die "cannot create $poabodyfile\n";
        }
    }
    my $adaname = join ".", @scopestack;
    if (exists $helpers{lc $adaname}) {
        my $helperspec = specfilename($basename, "helper");
        my $helperbody = bodyfilename($basename, "helper");
        $hsfh = $hlp_spec_file_handle[$#scopestack];
        $hbfh = $hlp_body_file_handle[$#scopestack];
        open($hsfh, ">$helperspec")
                or die "cannot create file $helperspec\n";
        open($hbfh, ">$helperbody")
                or die "cannot create file $helperbody\n";
        $opened_helper[$#scopestack] = 1;
        ehspec "with System, C_Strings, CORBA.C_Types;\n";
        if ($need_exceptions || $gen_tc_any) {
            ehspec "with System.Address_To_Access_Conversions;\n";
            if ($gen_tc_any) {
                ehbody "with Unchecked_Conversion;\n";
                if ($target_system == $CORBAWARE) {
                    ehbody "with CORBA.Basic_Object;\n";
                } else {
                    ehbody "with CORBA.Object;\n";
                }
                ehbody "\n";
            }
        }
        if ($need_unbounded_seq) {
            ehspec "with CORBA.C_Types.Simple_Unbounded_Seq, " .
                        "CORBA.C_Types.Unbounded_Seq;\n";
            ehspec "with CORBA.C_Types.Unbounded_Tagged_Seq;\n";
        }
        if ($need_bounded_seq) {
            ehspec "with CORBA.C_Types.Simple_Bounded_Seq, " .
                        "CORBA.C_Types.Bounded_Seq;\n";
        }
    }
    my $is_module = ($type == $CORBA::IDLtree::MODULE);
    push @indentlvl, 0;
    print_specfile_prologue($adaname, $is_module);
    print_bodyfile_prologue($adaname) unless ($is_module);
    print_ospecfile_prologue($adaname);
    print_obodyfile_prologue($adaname);
    if (! $is_module) {
        if ($gen_ispec[$#scopestack]) {
            print_ispecfile_prologue($adaname);
        }
        if ($gen_ibody[$#scopestack]) {
            print_ibodyfile_prologue($adaname);
        }
    }
    push @withlist, $adaname;
    print_withlist($adaname, $is_module);
    if (exists $helpers{lc $adaname}) {
        ehspec "\n";
        ehboth "package ";
        ehbody "body ";
        ehboth "$adaname.Helper is\n\n";
    }
}


sub search_enum_literal {
    my $symroot = shift;
    my $scope = shift;
    my $inside_includefile = shift;
    if (! isnode($symroot)) {
        return;
    }
    my @node = @{$symroot};
    if ($node[$TYPE] == $CORBA::IDLtree::ENUM) {
        foreach $literal (@{$node[$SUBORDINATES]}) {
            if ($gsearch_symbol eq $literal) {
                $gsearch_result = $symroot;
                last;
            }
        }
    }
}

sub charlit {
    my $input = shift;
    my $outbufref = shift;
    my $pos = 0;
    if ($input !~ /^\\/) {
        $$outbufref = substr($input, $pos, 1);
        return 1;
    }
    my $ch = substr($input, ++$pos, 1);
    my $consumed = 2;
    my $output = "Character'Val ";
    if ($ch eq 'n') {
        $output .= '(10)';
    } elsif ($ch eq 't') {
        $output .= '(9)';
    } elsif ($ch eq 'v') {
        $output .= '(11)';
    } elsif ($ch eq 'b') {
        $output .= '(8)';
    } elsif ($ch eq 'r') {
        $output .= '(13)';
    } elsif ($ch eq 'f') {
        $output .= '(12)';
    } elsif ($ch eq 'a') {
        $output .= '(7)';
    } elsif ($ch eq 'x') {         # hex number
        my $tuple = substr($input, ++$pos, 2);
        if ($tuple !~ /[0-9a-f]{2}/i) {
            $output = $ch;
            print "unknown escape \\x$tuple in string\n";
        } else {
            $output .= "(16#" . $tuple . "#)";
            $consumed += 2;
        }
    } elsif ($ch eq '0' or $ch eq '1') {     # octal number
        my $triple = substr($input, $pos, 3);
        if ($triple !~ /[0-7]{3}/) {
            $output = $ch;
            print "unknown escape \\$triple in string\n";
        } else {
            $output .= "(8#" . $triple . "#)";
            $consumed += 2;
        }
    } else {
        $output = $ch;
        print("unknown escape \\$ch in string\n") if ($ch =~ /[0-9A-z]/);
    }
    $$outbufref = $output;
    $consumed;
}

sub cvt_expr {
    my $lref = shift;
    my $charlit_output;
    my $output = "";

    foreach $input (@$lref) {
# print "cvt input = $input\n";
        my $ch = substr($input, 0, 1);
        if ($ch eq '"') {
            my $need_endquote = 1;
            $output .= '"';
            my $i;
            for ($i = 1; $i < length($input) - 1; $i++) {
                my $consumed = charlit(substr($input, $i), \$charlit_output);
                $i += $consumed - 1;
                if ($consumed > 1) {
                    $output .= '" & ';
                }
                $output .= $charlit_output;
                if ($consumed > 1) {
                    if ($i >= length($input) - 2) {
                        $need_endquote = 0;
                    } else {
                        # We had an escape, and are not yet at the end, so
                        # need to reopen the string
                        $output .= ' & "';
                    }
                }
            }
            if ($need_endquote) {
                $output .= '"';
            }
        } elsif ($ch eq "'") {
            my $consumed = charlit(substr($input, 1), \$charlit_output);
            if ($consumed == 1) {
                $output .= " '" . $charlit_output . "'";
            } else {
                $output .= " " . $charlit_output;
            }
        } elsif ($ch =~ /\d/) {
            if ($ch eq '0') {                   # check for hex/octal
                my $nxt = substr($input, 1, 1);
                if ($nxt eq 'x') {                  # hex const
                    $output .= ' 16#' . substr($input, 2) . '#';
                    next;
                } elsif ($nxt =~ /[0-7]/) {         # octal const
                    $output .= ' 8#' . substr($input, 1) . '#';
                    next;
                }
            }
            $output .= ' ' . $input;
        } elsif ($ch eq '.') {
            $output .= '0' . $input;
        } else {
            $gsearch_symbol = $input;
            $gsearch_result = 0;
            CORBA::IDLtree::traverse_tree($global_symroot,
                                          \&search_enum_literal, 1);
            if ($gsearch_result) {
                my @enumnode = @{$gsearch_result};
                $output .= ' ' . $enumnode[$NAME] . "\'Pos ($input)"
            } else {
                $output .= ' ' . $input;
            }
        }
    }
    $output;
}


sub isnode {
    CORBA::IDLtree::isnode(shift);
}


sub needs_IDL_FILE {
    my $noderef = shift;
    if (not isnode $noderef) {
        return 0;
    }
    my $type = $$noderef[$TYPE];
    if ($type == $CORBA::IDLtree::MODULE ||
        $type == $CORBA::IDLtree::INTERFACE ||
        $type == $CORBA::IDLtree::INCFILE ||
        $type == $CORBA::IDLtree::PRAGMA_PREFIX) {
        return 0;
    }
    not $type[$SCOPEREF];
}


sub prefix {
    # Package prefixing is only needed if the type referenced is
    # in a different scope.
    my $type = shift;
    my $gen_c_name = 0;
    if (@_) {
        $gen_c_name = shift;
    }
    my $separator = ($gen_c_name ? '_' : '.');
    if (! isnode $type) {
        print "info: prefix called on non-node ($type)\n";
        return "";
    }
    my @node = @{$type};
    my $prefix = "";
    my @scope;
    while ((@scope = @{$node[$SCOPEREF]})) {
        $prefix = $scope[$NAME] . $separator . $prefix;
        @node = @scope;
    }
    if (! $gen_c_name) {
        my $curr_scope = join('.', @scopestack) . '.';
        if ($prefix eq $curr_scope) {
            $prefix = "";
        } elsif (! $prefix and needs_IDL_FILE $type) {
            $prefix = $global_scope_pkgname . '.';
        }
    }
    $prefix;
}


sub helper_prefix {
    # NB: while sub prefix returns a dot-terminated prefix,
    # sub helper_prefix does not.
    my $type = shift;
    if ($type == $CORBA::IDLtree::BOOLEAN ||
        $type == $CORBA::IDLtree::STRING ||
        $type == $CORBA::IDLtree::WSTRING ||
        $type == $CORBA::IDLtree::SEQUENCE ||
        $type == $CORBA::IDLtree::ANY) {
        return "CORBA.C_Types";
    }
    if (not isnode $type) {
        die "helper_prefix called on non-node ($type)\n";
    }
    my @node = @{$type};
    my $prefix = "";
    my @scope;
    while ((@scope = @{$node[$SCOPEREF]})) {
        $prefix = $scope[$NAME] . '.' . $prefix;
        @node = @scope;
    }
    if (! $prefix and needs_IDL_FILE $type) {
        $prefix = $global_scope_pkgname . '.';
    }
    $prefix . "Helper";
}


sub c_var_type {
    my $type = shift;
    my $is_return_type = 0;
    my $rv;
    if (@_) {
        $is_return_type = shift;
    }
    my $return_by_reference = 0;
    if ($is_return_type && return_by_reference($type)) {
        $return_by_reference = 1;
    }
    if (is_a($type, $CORBA::IDLtree::BOOLEAN)) {
        $rv = "CORBA.Char";
    } elsif (is_a($type, $CORBA::IDLtree::STRING) ||
             is_a($type, $CORBA::IDLtree::BOUNDED_STRING)) {
        $rv = "C_Strings.Chars_Ptr";
    } elsif (is_a($type, $CORBA::IDLtree::WSTRING) ||
             is_a($type, $CORBA::IDLtree::BOUNDED_WSTRING)) {
        $rv = "CORBA.C_Types.WString_Ptr";
    } elsif (is_a($type, $CORBA::IDLtree::ANY)) {
        $rv = "CORBA.C_Types.C_Any";
        if ($return_by_reference) {
            $rv .= "_Access";
        }
    } elsif (is_objref $type) {
        $rv = "System.Address";
    } elsif (! isnode($type) or ! is_complex($type)) {
        $rv = mapped_type($type);  # the Ada type
        if ($return_by_reference) {
            my $typnam = $rv;
            # eliminate possible helper prefix
            $typnam =~ s/^.+\.(\w+)$/$1/;
            $rv = helper_prefix($type) . ".C_${typnam}_Access";
        }
    } else {
        my $helper = helper_prefix($type);
        my @node = @{$type};
        if (is_a($type, $CORBA::IDLtree::STRUCT) ||
            is_a($type, $CORBA::IDLtree::UNION)) {
            $rv = $helper . ".C_" . $node[$NAME];
            if ($return_by_reference) {
                $rv .= "_Access";
            }
        } elsif (is_a($type, $CORBA::IDLtree::SEQUENCE)) {
            $rv = "CORBA.C_Types.C_Sequence";
            if ($is_return_type) {
                $rv .= "_Access";
            }
        } elsif ($$type[$TYPE] == $CORBA::IDLtree::TYPEDEF) {
            my @origtype_and_dim = @{$node[$SUBORDINATES]};
            if ($origtype_and_dim[1] && @{$origtype_and_dim[1]}) {
                $rv = $helper . ".C_" . $node[$NAME];
                if ($is_return_type) {
                    $rv .= "_Access";
                }
            } else {
                $rv = c_var_type($origtype_and_dim[0], $is_return_type);
            }
        } else {
            $rv = "<c_var_type UFO>";
        }
    }
    $rv;
}


sub seq_pkgname {
    my $seqtype = shift;
    my $lang_c = 0;
    if (@_) {
        $lang_c = shift;
    }
    if (! isnode($seqtype) || $$seqtype[$TYPE] != $CORBA::IDLtree::SEQUENCE) {
        print "internal error: seq_pkgname called on non-sequence\n";
        return "";
    }
    my @node = @{$seqtype};
    my $bound = "";
    if ($node[$NAME]) {
        $bound = $node[$NAME] . '_';
    }
    my $elemtype = CORBA::IDLtree::typeof($node[$SUBORDINATES]);
    my $rv;
    if ($lang_c) {
        $rv = helper_prefix($seqtype) . ".C_Seq_$bound$elemtype";
    } else {
        $rv = prefix($seqtype) . "IDL_Sequence_$bound$elemtype";
    }
    $rv;
}


sub mapped_type {
    my $type = shift;
    CORBA::IDLtree::typeof($type, $CORBA::IDLtree::LANG_ADA, \@scopestack);
}


sub check_sequence {
    # Bounded strings are also handled here.
    my $type_descriptor = shift;
    my $adatype = mapped_type($type_descriptor);
    if (not isnode $type_descriptor) {
        return $adatype;
    }
    my @node = @{$type_descriptor};
    # Generate C<=>Ada conversion functions for bounded strings
    if ($node[$TYPE] == $CORBA::IDLtree::BOUNDED_STRING ||
        $node[$TYPE] == $CORBA::IDLtree::BOUNDED_WSTRING) {
        my $w = ($node[$TYPE] == $CORBA::IDLtree::BOUNDED_WSTRING);
        my $wide = ($w ? "Wide_" : "");
        my $ctype = ($w ? "CORBA.C_Types.WString_Ptr" : "C_Strings.Chars_Ptr");
        phboth "function To_C (From : $adatype)\n";
        phboth "              return $ctype";
        ehspec ";\n";
        ehbody " is\n";
        phbody "begin\n";
        my $pkg = "CORBA.Bounded_${wide}String_" . $node[$NAME];
        phbody "   return CORBA.C_Types.To_C ($pkg\.To_${wide}String (From));\n";
        phbody "end To_C;\n\n";
        phboth "function To_Ada (From : $ctype)\n";
        phboth "                return $adatype";
        ehspec ";\n\n";
        ehbody " is\n";
        phbody "begin\n";
        phbody "   return $pkg\.To_Bounded_${wide}String (";
        if ($w) {
            ehbody "CORBA.C_Types.To_Ada";
        } else {
            ehbody "C_Strings.Value";
        }
        ehbody " (From));\n";
        phbody "end To_Ada;\n\n";
        return $adatype;
    } elsif ($node[$TYPE] != $CORBA::IDLtree::SEQUENCE) {
        return $adatype;
    }
    # Now it's actually a sequence.
    my $element_type = $node[$SUBORDINATES];
    if (isnode $element_type and
        $$element_type[$TYPE] == $CORBA::IDLtree::SEQUENCE) {
        check_sequence($element_type);
    }
    my $bound = $node[$NAME];
    my $eletypnam = mapped_type($element_type);
    my $boundtype = ($bound) ? "Bounded" : "Unbounded";
    # take care of the Proxy spec
    my $pkgname = seq_pkgname($type_descriptor);
    ppspec "package $pkgname is new\n";
    ppspec "   CORBA.Sequences.$boundtype ($eletypnam";
    epspec(", " . $bound) if ($bound);
    epspec ");\n\n";
    # take care of the Helper spec
    my $cplx = is_complex($element_type);
    my $celetypnam;
    $celetypnam = CORBA::IDLtree::typeof($element_type, $GEN_C_TYPE, 1);
    my $seq_hlppkg = seq_pkgname($type_descriptor, $GEN_C_TYPE);
    # Remove helper package prefix because we're there already.
    $seq_hlppkg =~ s/^.*\.//;
    my $allocfun = "${seq_hlppkg}_allocbuf";
    phspec "function $allocfun (Length : CORBA.Unsigned_Long)\n";
    phspec "         return System.Address;\n";
    phspec "pragma Import (C, $allocfun,\n";
    phspec "               \"CORBA_sequence_${celetypnam}_allocbuf\");\n\n";
    my $simple = ($cplx ? "" : "Simple_");
    my $is_objtype = is_objref($element_type);
    my $tagged = ($is_objtype ? "Tagged_" : "");
    phspec "package $seq_hlppkg is new CORBA.C_Types.";
    ehspec "$simple${boundtype}_${tagged}Seq\n";
    phspec "  ($eletypnam, ";
    if ($bound) {
        ehspec "$bound, ";
    }
    ehspec("$pkgname, $allocfun");
    if ($cplx and not $is_objtype) {
        my $hlpkg = helper_prefix($element_type);
        $celetypnam = c_var_type($element_type);
        ehspec ",\n";
        phspec "   $celetypnam, $hlpkg.To_C, $hlpkg.To_Ada";
    }
    ehspec ");\n\n";
    $pkgname . ".Sequence";
}


sub mangled_scope {
    my $scoperef = shift;
    my $called_for_methodname = 0;
    if (@_) {
       $called_for_methodname = shift;
    }
    my $result = "";
    my $count = 0;
    while ($scoperef) {
        my @node = @{$scoperef};
        $result = length($node[$NAME]) . $node[$NAME] . $result;
        $count++;
        $scoperef = $node[$SCOPEREF];
    }
    if ($count) {
        if ($called_for_methodname) {
            if (--$count == 0) {
                return $result;
            }
        }
        if ($cplusplus == $GPP) {
            $count++;
        }
        $result = "Q$count" . $result;
    }
    $result;
}


sub mangled_name {
    my $name = shift;
    my $paramlist_ref = shift;
    my $scoperef = shift;
    my $origname = $name;
    # New method: really CONSTRUCT the mangled name, no cheating ;)
    $name .= "__" . mangled_scope($scoperef, 1);
    if ($cplusplus == $DECCXX) {
        $name .= 'X';
    }
    # from CORBA::IDLtree :  @predef_types = 
    #               none boolean octet char wchar short long long_long 
    my @elemcode = ( 'ERROR', 'Uc', 'Uc', 'c', 'Wc', 's', 'l', 'x',
    #               unsigned_short unsigned_long unsigned_long_long
                     'Us', 'Ul', 'Ux',
    #               float double long_double string wstring Object 
                     'f', 'd', 'r', 'Pc', 'PWc', '12CORBA_Object' );
    if ($arch == 64) {
        $elemcode[$CORBA::IDLtree::LONG] = 'i';
        $elemcode[$CORBA::IDLtree::LONG_LONG] = 'l';
        $elemcode[$CORBA::IDLtree::UNSIGNED_LONG] = 'Ui';
        $elemcode[$CORBA::IDLtree::UNSIGNED_LONG_LONG] = 'Ul';
    }
    # The others, i.e.
    #               TypeCode any fixed bounded_string
    #               sequence enum typedef struct union case default
    #               exception const module interface interface attribute
    #               oneway void method include pragma_prefix 
    # are handled separately.

    foreach $param (@$paramlist_ref) {
        my $type = $$param[$TYPE];
        my $mode = $$param[$MODE];
        my $el_index = CORBA::IDLtree::is_elementary_type($type);
        if ($el_index) {
            if ($el_index == $CORBA::IDLtree::STRING) {
                if ($mode == $CORBA::IDLtree::IN) {
                    $name .= 'PCc';
                } elsif ($mode == $CORBA::IDLtree::INOUT) {
                    $name .= 'RPc';
                } else {
                    $name .= '16CORBA_String_out';
                }
            } else {
                if ($mode != $CORBA::IDLtree::IN) {
                    $name .= 'R';
                }
                $name .= $elemcode[$el_index];
            }
        } else {
            $name .= 'R';
            if ($mode == $CORBA::IDLtree::IN) {
                $name .= 'C';
            }
            $name .= mangled_scope($$type[$SCOPEREF]);
            $name .= length($$type[$NAME]) . $$type[$NAME];
        }
    }
    $name .= "R17CORBA_Environment";
    # Try to verify constructed symbol by doing an `nm' on the C++ object file
    my $object_file = lc($global_idlfile);
    $object_file =~ s/\.idl/C.o/;
    if (not (-e $object_file)) {
        print("cannot verify $name because can't find $object_file\n");
        return $name;
    }
    my $nmcmd = "nm ";
    if ($cplusplus == $DECCXX) {
        $nmcmd .= "-mangled_name_only ";
    }
    $nmcmd .= "$object_file | grep ";
    my $cmdline = $nmcmd . $name;
    # if (! open(NM, "$cmdline |")) {
    #     print "mangled_name : can't run nm\n";
    #     return $name;
    # }
    # my $found = <NM>;
    # close NM;
    my $found = `$cmdline`;
    if ($found) {
        return $name;
    }
    print "could not find $name in $object_file\n";
    # Hmph, construction was haywire.
    # So let's try find an approximate match in the object file.
    $cmdline = "${nmcmd}${origname}__.*R17CORBA_Environment";
    if (! open(NM, "$cmdline |")) {
        print "mangled_name : can't run nm (2)\n";
        return $origname;         # It's bad.. but this never happens
    }
    my $count = 0;
    my @line;
    while (<NM>) {
        chop;
        $line[$count++] = $_;
    }
    close NM;
    if (! $count) {
        print "mangled_name: $cmdline yields no matches\n";
        return "$origname\__FILL_THIS_IN_MANUALLY";
    }
    $count--;
    if ($count > 0) {
        print "mangled_name($origname): there were several matches.\n";
        print "Please select the number of the appropriate symbol:\n";
        my $i;
        for ($i = 0; $i <= $count; $i++) {
            print "\t$i => $line[$i]\n";
        }
        $count = <STDIN>;
    }
    my @nm_info = split /\s/, $line[$count];
    foreach (@nm_info) {
        if (/R17CORBA_Environment/) {
            return $_;
        }
    }
    print "mangled_name: couldn't find $searchsym in $object_file\n";
    "$origname\__FILL_THIS_IN_MANUALLY";
}


sub pass_by_reference {
    my $type = shift;
    if (! isnode($type)) {
        return 0;
    }
    my @node = @{$type};
    my $rv = 0;
    if ($node[$TYPE] == $CORBA::IDLtree::TYPEDEF) {
        my @origtype_and_dim = @{$node[$SUBORDINATES]};
        if ($origtype_and_dim[1] && @{$origtype_and_dim[1]}) {
            $rv = 1;
        } else {
            $rv = pass_by_reference($origtype_and_dim[0]);
        }
    } elsif ($node[$TYPE] == $CORBA::IDLtree::ANY ||
             $node[$TYPE] == $CORBA::IDLtree::SEQUENCE ||
             $node[$TYPE] == $CORBA::IDLtree::STRUCT ||
             $node[$TYPE] == $CORBA::IDLtree::UNION) {
        $rv = 1;
    }
    $rv;
}


sub set_c_ref {
    # NB: set_c_ref returns an entire statement
    #     while get_c_ref returns just a right-hand-side expression
    my $destobj = shift;
    my $srcaddr = shift;
    my $rv = "CORBA.";
    if ($target_system == $CORBAWARE) {
        $rv .= "Basic_";
    }
    $rv .= "Object.Set_C_Ref ($destobj, $srcaddr);\n";
    $rv;
}

sub get_c_ref {
    my $srcobj = shift;
    my $rv = "CORBA.";
    if ($target_system == $CORBAWARE) {
        $rv .= "Basic_";
    }
    $rv .= "Object.Get_C_Ref ($srcobj)";
    $rv;
}


sub c2ada {
    my $target = shift;
    my $varname = shift;
    my $type = shift;
    my $mode = $CORBA::IDLtree::IN;
    if (@_) {
        $mode = shift;
    }
    my $assign_to_adatemp = ($target =~ /^AdaTemp/);
    if (is_objref $type) {
        if ($mode != $CORBA::IDLtree::IN && $assign_to_adatemp) {
            $varname .= ".all";
        }
        return set_c_ref($target, $varname);
    }
    my $cplx = is_complex($type);
    my $rv;
    my $assign_from_ctemp = 0;
    if ($varname =~ /^CTemp_/) {
        $assign_from_ctemp = 1;
    }
    my $is_return_type = ($target eq "Returns");
    if ($varname eq "CTemp_Returns") {
        $is_return_type = 1;
    }
    my $return_by_reference = 0;
    if ($is_return_type && $assign_from_ctemp &&
        return_by_reference($type)) {
        $return_by_reference = 1;
    }
    if ($cplx == 0) {
        my $adatype = mapped_type($type);
        my $ctype = c_var_type($type);
        if ($ctype ne $adatype) {
            return "<ERROR: c2ada Ada /= C of $varname>";
        }
        $rv = $varname;
        if ($return_by_reference) {
            $rv .= ".all";
        }
    } elsif (CORBA::IDLtree::is_elementary_type($type, 1)) {
        $rv = $varname;
        if ($mode != $CORBA::IDLtree::IN && $assign_to_adatemp ||
            is_a($type, $CORBA::IDLtree::ANY) &&
               ($assign_to_adatemp || $mode == $CORBA::IDLtree::OUT)) {
            $rv .= ".all";
        }
        $rv = "CORBA.C_Types.To_Ada ($rv)";
        if (isnode $type and $$type[$TYPE] == $CORBA::IDLtree::TYPEDEF) {
            $rv = mapped_type($type) . " ($rv)";
        }
    } else {
        my @node = @{$type};
        my $hlpprefix = helper_prefix($type);
        if ($node[$TYPE] == $CORBA::IDLtree::TYPEDEF) {
            my @origtype_and_dim = @{$node[$SUBORDINATES]};
            my $origtype = $origtype_and_dim[0];
            my $dim = $origtype_and_dim[1];
            if ($dim && @{$dim}) {
                $rv = $varname;
                if ($mode != $CORBA::IDLtree::IN) {
                    if ($return_by_reference ||
                        $mode == $CORBA::IDLtree::OUT && is_variable($type) ||
                        ! $assign_from_ctemp) {
                        $rv .= ".all";
                    }
                }
                $rv = "$hlpprefix.To_Ada ($rv)";
            } elsif ($$origtype[$TYPE] == $CORBA::IDLtree::BOUNDED_STRING ||
                     $$origtype[$TYPE] == $CORBA::IDLtree::BOUNDED_WSTRING) {
                # We have to use an ugly local declare because there might
                # be several different bounded-string typedefs and then
                # inline casting results in an overload resolution problem
                # (poor ole compiler doesn't know which To_Ada we mean.)
                my $tgt = ($assign_to_adatemp ? "AdaTemp" : "Tmp");
                $rv = "declare\n         $tgt : " .
                       mapped_type($origtype) .
                       ";\n      begin\n         " .
                       c2ada($tgt, $varname, $origtype, $mode) .
                       "         $target := " . prefix($type) .
                       $node[$NAME] . " ($tgt);\n      end;\n";
                $target = "";
            } else {
                # Special call: empty target means return just RHS
                $rv = c2ada("", $varname, $origtype, $mode);
                $rv = mapped_type($type) . " ($rv)";
            }
        } elsif ($node[$TYPE] == $CORBA::IDLtree::SEQUENCE) {
            $rv = $varname;
            if ($mode != $CORBA::IDLtree::IN) {
                if ($return_by_reference || ! $assign_from_ctemp ||
                    (! $is_return_type &&
                     is_variable($type) && $mode == $CORBA::IDLtree::OUT)) {
                    $rv .= ".all";
                }
            }
            $rv = seq_pkgname($type, $GEN_C_TYPE) . ".Create ($rv)";
        } else {
            $rv = $varname;
            if ($mode != $CORBA::IDLtree::IN &&
                ($node[$TYPE] != $CORBA::IDLtree::BOUNDED_STRING &&
                 $node[$TYPE] != $CORBA::IDLtree::BOUNDED_WSTRING ||
                 $assign_to_adatemp)) {
                if ($return_by_reference || ! $assign_from_ctemp ||
                    (! $is_return_type && is_variable($type) &&
                     $mode == $CORBA::IDLtree::OUT)) {
                    $rv .= ".all";
                }
            }
            if (! is_complex($type, $ANALYZE_UNION)) {   # case of simple union
                $rv .= ".Wrapped";
            } else {
                $rv = "$hlpprefix.To_Ada ($rv)";
            }
        }
    }
    if ($target) {
       $rv = "$target := $rv;\n";
    }
    $rv;
}


sub ada2c {
    my $varname = shift;
    my $type = shift;
    my $cplx = is_complex($type);
    my $rv = $varname;
    if (! $cplx) {
        my $adatype = mapped_type($type);
        my $ctype = c_var_type($type);
        if ($ctype ne $adatype) {
            return "<ERROR: ada2c Ada /= C of $varname>";
        }
    } elsif (is_objref $type) {
        $rv = get_c_ref($rv);
    } elsif (CORBA::IDLtree::is_elementary_type($type, 1)) {
        if (isnode($type) && $$type[$TYPE] == $CORBA::IDLtree::TYPEDEF) {
            $rv = mapped_type($cplx) . " ($rv)";
        }
        $rv = "CORBA.C_Types.To_C ($rv)";
    } else {
        my @node = @{$type};
        my $hlpprefix = helper_prefix($type);
        if ($node[$TYPE] == $CORBA::IDLtree::TYPEDEF) {
            my @origtype_and_dim = @{$node[$SUBORDINATES]};
            my $origtype = $origtype_and_dim[0];
            my $dim = $origtype_and_dim[1];
            if ($dim && @{$dim}) {
                $rv = "$hlpprefix.To_C ($rv)";
            } else {
                $type = $$origtype[$TYPE];
                if ($type == $CORBA::IDLtree::SEQUENCE) {
                    $rv = seq_pkgname($origtype, $GEN_C_TYPE) . ".Create\n";
                    $rv .= "          (" . seq_pkgname($origtype) .
                           ".Sequence ($varname))";
                } else {
                    if ($type == $CORBA::IDLtree::BOUNDED_STRING) {
                        $rv = mapped_type($origtype) . " ($varname)";
                    }
                    $rv = "$hlpprefix.To_C ($rv)";
                }
            }
        } elsif ($node[$TYPE] == $CORBA::IDLtree::SEQUENCE) {
            $rv = seq_pkgname($type, $GEN_C_TYPE) . ".Create ($varname)";
        } elsif (! is_complex($type, $ANALYZE_UNION)) {   # simple union
            $rv = "$hlpprefix.C_" . $$type[$NAME] . "\' (Wrapped => $varname)";
        } else {
            $rv = "$hlpprefix.To_C ($rv)";
        }
    }
    $rv;
}


sub make_c_interfacing_var {
    my $type = shift;
    my $name = shift;
    my $mode = shift;
    my $caller_already_added_return_param = 0;
    if (@_) {
        $caller_already_added_return_param = shift;
    }
    my $is_return_type = ($name eq "Returns");
    if ($mode != $CORBA::IDLtree::IN or is_complex($type) or
        ($is_return_type and return_by_reference $type)) {
        ppbody "CTemp_$name : ";
        my $ctype = c_var_type($type, $is_return_type);
        if (! $is_return_type && ($mode != $CORBA::IDLtree::IN ||
                                  is_a($type, $CORBA::IDLtree::ANY))) {
            epbody "aliased ";
        }
        epbody "$ctype";
        if (! $is_return_type && is_variable($type) &&
            $mode == $CORBA::IDLtree::OUT && ! is_a_string($type)) {
            epbody "_Access";
        }
        epbody ";\n";
    }
    if (! is_objref($type) && ! $caller_already_added_return_param &&
        $name eq "Returns") {
        ppbody("Returns : " . mapped_type($type) . ";\n");
    }
}

sub c_var_name {
    my $type = shift;
    my $name = shift;
    my $mode = $CORBA::IDLtree::IN;
    if (@_) {
       $mode = shift;
    }
    if ($mode != $CORBA::IDLtree::IN or is_complex $type) {
        $name = "CTemp_" . $name;
    }
    $name;
}

sub ada_from_c_var {
    my $type = shift;
    my $name = shift;
    my $mode = shift;
    my $gen_adatemp_assignment = 0;
    if (@_) {
        $gen_adatemp_assignment = shift;
    }
    my ($a, $c);
    if ($gen_adatemp_assignment) {
        $a = "AdaTemp_$name";
        $c = $name;
    } else {
        $a = $name;
        $c = "CTemp_$name";
    }
    if ($mode == $CORBA::IDLtree::IN) {
        unless ($gen_adatemp_assignment) {
            if (is_a_string($type) || is_a($type, $CORBA::IDLtree::ANY)) {
                ppbody(freeproc($type) . " ($c");
                if (is_a($type, $CORBA::IDLtree::ANY)) {
                   epbody "\'Access";
                }
                epbody ");\n";
            }
            return;
        }
        if (! pass_by_reference($type) && ! is_complex($type)) {
            return;
        }
    }
    my $stmt = c2ada($a, $c, $type, $mode);
    if ($gen_adatemp_assignment) {
        if ($mode != $CORBA::IDLtree::OUT) {
            pobody($stmt) if ($stmt ne "$a := $c;\n");
        }
    } else {
        ppbody $stmt;
        if (($a eq "Returns" and return_by_reference $type) or
            ($mode == $CORBA::IDLtree::OUT and is_variable $type) or
            is_a_string($type) or is_a($type, $CORBA::IDLtree::ANY)) {
            ppbody(freeproc($type) . " ($c");
            if ($a ne "Returns" && is_a($type, $CORBA::IDLtree::ANY) &&
                $mode != $CORBA::IDLtree::OUT) {
               epbody "\'Access";
            }
            epbody ");\n";
        }
    }
}

sub make_ada_interfacing_var {
    my $type = shift;
    my $name = shift;

    if (is_complex($type)) {
        pobody("AdaTemp_$name : " . mapped_type($type) . ";\n");
    }
}

sub ada_var_name {
    my $type = shift;
    my $name = shift;

    if (is_complex $type) {
        $name = "AdaTemp_" . $name;
    }
    $name;
}

sub c_from_ada_var {
    my $type = shift;
    my $name = shift;
    my $mode = shift;
    my $gen_ctemp_assignment = 0;
    if (@_) {
        $gen_ctemp_assignment = shift;
    }
    my ($c, $a);
    if ($mode == $CORBA::IDLtree::IN &&
        (! $gen_ctemp_assignment || ! is_complex($type))) {
        return;
    }
    my $is_simple_union = 0;
    if ($gen_ctemp_assignment) {
        $c = "CTemp_$name";
        $a = $name;
    } else {
        $c = $name;
        if ($c ne "Returns" && $mode != $CORBA::IDLtree::IN) {
            $c .= ".all";
        }
        $a = "AdaTemp_$name";
    }
    my $converted = ada2c($a, $type);
    my $var_out = ($c ne "Returns" &&
                   is_variable($type) && $mode == $CORBA::IDLtree::OUT);
    if (! $gen_ctemp_assignment && $var_out) {
        $converted = dupproc($type) . " ($converted)";
    }
    my $stmt = "$c := $converted;\n";
    if ($gen_ctemp_assignment) {
        if (! $var_out) {
            ppbody $stmt;
        }
    } else {
        if ($a ne $converted or $is_simple_union) {
            pobody $stmt;
        }
    }
}


sub subprog_param_text {
    my $ptype = shift;
    my $pname = shift;
    my $pmode = shift;
    my $make_c_type = 0;
    if (@_) {
        $make_c_type = shift;
    }
    my $by_reference = 0;
    if ($pmode == $CORBA::IDLtree::OUT && is_variable($ptype)) {
        $by_reference = 1;
    }
    my $adatype = mapped_type($ptype);
    my $adamode = ($pmode == $CORBA::IDLtree::IN ? 'in' :
                   $pmode == $CORBA::IDLtree::OUT ? 'out' : 'in out');
    if ($make_c_type) {
        $adatype = c_var_type($ptype, $by_reference);
        if ($pmode != $CORBA::IDLtree::IN ||
            is_a($ptype, $CORBA::IDLtree::ANY)) {
            $adamode = 'access';
            # This MUST be access mode because it might be a non-void
            # IDL function with inout or out parameters.
        }
    } elsif (is_objref $ptype) {
        $adatype .= "\'Class";
    }
    "$pname : $adamode $adatype";
}


sub is_a {
    # Determines whether node is of given type. Recurses through TYPEDEFs.
    my $type = shift;
    my $typeid = shift;
    if ($type == $typeid) {
        return 1;
    } elsif (not isnode $type) {
        return 0;
    }
    my @node = @{$type};
    my $rv = 0;
    if ($node[$TYPE] == $typeid) {
        $rv = 1;
    } elsif ($node[$TYPE] == $CORBA::IDLtree::TYPEDEF) {
        my @origtype_and_dim = @{$node[$SUBORDINATES]};
        my $dimref = $origtype_and_dim[1];
        unless ($dimref && @{$dimref}) {
            $rv = is_a($origtype_and_dim[0], $typeid);
        }
    }
    $rv;
}


sub is_a_string {
    my $type = shift;
    is_a($type, $CORBA::IDLtree::STRING) ||
     is_a($type, $CORBA::IDLtree::BOUNDED_STRING) ||
      is_a($type, $CORBA::IDLtree::WSTRING) ||
       is_a($type, $CORBA::IDLtree::BOUNDED_WSTRING);
}


sub is_complex {
    # Returns 0 if representation of type is same in C and Ada.
    # Returns the numeric code of the type (as defined in CORBA::IDLtree)
    #   for types represented differently between C and Ada.
    # If the optional $analysis_mode arg is not supplied or is 0,
    #   then in the case of a typedef, is_complex analyzes the typedef'ed
    #   type for structural difference between the C and the Ada
    #   representation.
    # If the $analysis_mode is given as $DONT_ANALYZE_ARRAY, then
    #   is_complex returns $CORBA::IDLtree::TYPEDEF for a typedef
    #   if the new type defined is an array.
    # If the $analysis_mode is given as $ANALYZE_UNION, then is_complex
    #   returns 0 for fixed unions. (Normally, is_complex will return
    #   $CORBA::IDLtree::UNION for any kind of union.)
    my $type = shift;
    my $analysis_mode = 0;
    if (@_) {
        $analysis_mode = shift;
    }
    if ($type == $CORBA::IDLtree::BOOLEAN ||
        $type == $CORBA::IDLtree::STRING ||
        $type == $CORBA::IDLtree::WSTRING ||
        $type == $CORBA::IDLtree::ANY ||
        $type == $CORBA::IDLtree::BOUNDED_STRING ||
        $type == $CORBA::IDLtree::BOUNDED_WSTRING ||
        $type == $CORBA::IDLtree::SEQUENCE ||
        $type == $CORBA::IDLtree::OBJECT) {
        return $type;
    } elsif ($type < $CORBA::IDLtree::NUMBER_OF_TYPES) {
        return 0;
    } elsif (not isnode $type) {
        die "is_complex called on non-node ($type)\n";
    }
    my @node = @{$type};
    my $t = $node[$TYPE];
    if ($t == $CORBA::IDLtree::ENUM ||
        $t == $CORBA::IDLtree::FIXED) {
        return 0;
    } elsif ($t == $CORBA::IDLtree::TYPEDEF) {
        my @origtype_and_dim = @{$node[$SUBORDINATES]};
        my $dimref = $origtype_and_dim[1];
        if ($dimref && @{$dimref} &&
            $analysis_mode == $DONT_ANALYZE_ARRAY) {
            return $CORBA::IDLtree::TYPEDEF;
        }
        return is_complex($origtype_and_dim[0]);
    } elsif ($t == $CORBA::IDLtree::INTERFACE ||
             $t == $CORBA::IDLtree::INTERFACE_FWD) {
        return $t;
    } elsif ($t == $CORBA::IDLtree::UNION &&
             $analysis_mode != $ANALYZE_UNION) {
        return $t;
    } elsif ($t != $CORBA::IDLtree::STRUCT &&
             $t != $CORBA::IDLtree::UNION &&
             $t != $CORBA::IDLtree::EXCEPTION) {
        return is_complex($t);
    }
    my @components = @{$node[$SUBORDINATES]};
    if ($t == $CORBA::IDLtree::UNION) {
        shift @components;   # discard discriminant
    }
    if ($analysis_mode != $ANALYZE_UNION) {
        # special TYPEDEF treatment only applies to outermost decl.
        $analysis_mode = 0;
    }
    foreach $component (@components) {
        if (is_complex($$component[$TYPE], $analysis_mode)) {
            return $t;
        }
    }
    0;
}


sub is_variable {
    my $type = shift;
    my $rv = 0;
    if ($type < $CORBA::IDLtree::NUMBER_OF_TYPES) {
        if ($type == $CORBA::IDLtree::STRING ||
            $type == $CORBA::IDLtree::WSTRING ||
            $type == $CORBA::IDLtree::ANY) {
            $rv = $type;
        }
        return $rv;
    }
    isnode($type) or die "param to is_variable is not a node\n";
    my @node = @{$type};
    my $t = $node[$TYPE];
    if ($t == $CORBA::IDLtree::BOUNDED_STRING ||
        $t == $CORBA::IDLtree::BOUNDED_WSTRING ||
        $t == $CORBA::IDLtree::SEQUENCE) {
        $rv = $t;
    } elsif ($t == $CORBA::IDLtree::TYPEDEF) {
        my @origtype_and_dim = @{$node[$SUBORDINATES]};
        $rv = is_variable($origtype_and_dim[0]);
    } elsif ($t == $CORBA::IDLtree::STRUCT ||
             $t == $CORBA::IDLtree::UNION) {
        my @components = @{$node[$SUBORDINATES]};
        if ($t == $CORBA::IDLtree::UNION) {
            shift @components;   # discard discriminant
        }
        foreach $component (@components) {
            if (is_variable $$component[$TYPE]) {
                $rv = $t;
                last;
            }
        }
    }
    $rv;
}


sub return_by_reference {
    my $type = shift;
    if ($type < $CORBA::IDLtree::NUMBER_OF_TYPES) {
        if ($type == $CORBA::IDLtree::ANY) {
            return 1;
        }
        return 0;
    }
    isnode($type) or die "param to return_by_reference is not a node\n";
    my @node = @{$type};
    my $t = $node[$TYPE];
    my $rv = 0;
    if ($t == $CORBA::IDLtree::SEQUENCE) {
        $rv = $t;
    } elsif ($t == $CORBA::IDLtree::TYPEDEF) {
        my @origtype_and_dim = @{$node[$SUBORDINATES]};
        my $dimref = $origtype_and_dim[1];
        if ($dimref && @{$dimref}) {
            $rv = $t;
        } else {
            $rv = return_by_reference($origtype_and_dim[0]);
        }
    } elsif ($t == $CORBA::IDLtree::STRUCT ||
             $t == $CORBA::IDLtree::UNION) {
        $rv = is_variable($type);
    }
    $rv;
}


sub is_objref {
    my $type = shift;
    is_a($type, $CORBA::IDLtree::OBJECT) ||
     is_a($type, $CORBA::IDLtree::INTERFACE) ||
      is_a($type, $CORBA::IDLtree::INTERFACE_FWD);
}


sub is_integer_type {
    my $type = shift;
    my $rv = 0;
    if ($type >= $CORBA::IDLtree::OCTET &&
        $type <= $CORBA::IDLtree::ULONGLONG) {
        $rv = $type;
    } elsif (isnode($type) && $$type[$TYPE] == $CORBA::IDLtree::TYPEDEF) {
        my @origtype_and_dim = @{$$type[$SUBORDINATES]};
        my $dimref = $origtype_and_dim[1];
        unless ($dimref && @{$dimref}) {
            $rv = is_integer_type($origtype_and_dim[0]);
        }
    }
    $rv;
}


sub pobody_beginmethod {
    pobody "Self : Object_Access := ";
    if ($target_system == $CORBAWARE) {
        eobody "To_Pointer (CORBA.BOA.Get_State (This));\n";
    } else {
        eobody "C_Map.Find (This);\n";
    }
    $indentlvl[$#indentlvl]--;
    pobody "begin\n";
    $indentlvl[$#indentlvl]++;
    pobody "if Self = null then\n";
    pobody "   raise CORBA.Object_Not_Exist;\n";
    pobody "end if;\n";
    if ($target_system == $CORBAWARE) {
        pobody "CORBA.Basic_Object.Set_C_Env (Self.all, Env.all);\n";
    }
}


sub const2ada {
    my $type = shift;
    my $expr = shift;
    if ($type == $CORBA::IDLtree::STRING) {
        return "CORBA.To_CORBA_String ($expr)";
    } elsif (isnode $type) {
        my @tn = @{$type};
        if ($tn[$TYPE] == $CORBA::IDLtree::BOUNDED_STRING) {
            return ("CORBA.Bounded_String_$tn[$NAME]" .
                    ".To_Bounded_String ($expr)");
        } elsif ($tn[$TYPE] == $CORBA::IDLtree::TYPEDEF) {
            my @origtype_and_dim = @{$tn[$SUBORDINATES]};
            return const2ada($origtype_and_dim[0], $expr);
        }
    }
    $expr;
}


sub array_range {
    my $dim = shift;
    my $is_enum_type = 0;
    my $range;
    if ($dim !~ /\D/) {         # if the dim is a number
        $range = $dim - 1;      # then use that number directly
    } else {                    # (else leave it to the Ada compiler)
        # As a non-standard IDL->Ada extension, we allow
        # an enum typename for the array size indication
        $CORBA::IDLtree::gsearch_symbol = $dim;
        $CORBA::IDLtree::gsearch_symbol =~ s/^.*\.//;
        $CORBA::IDLtree::gsearch_result = 0;
        CORBA::IDLtree::traverse_tree($global_symroot,
                                      \&CORBA::IDLtree::search_enum_type, 1);
        if ($CORBA::IDLtree::gsearch_result) {
            $range = $dim;
            $is_enum_type = 1;
        } else {
            # use cvt_expr in order to catch enum literal usage
            my @symlist = ($dim);
            $range = cvt_expr(\@symlist) . " - 1" ;
            $range =~ s/^\s*//;
        }
    }
    unless ($is_enum_type) {
        $range = "0 .. $range";
    }
    $range;
}


sub freeproc {
    my $type = shift;
    my $rv = "";
    if (is_a($type, $CORBA::IDLtree::STRING) ||
        is_a($type, $CORBA::IDLtree::BOUNDED_STRING)) {
        $rv = "CORBA.C_Types.Free";
    } elsif (is_a($type, $CORBA::IDLtree::WSTRING) ||
        is_a($type, $CORBA::IDLtree::BOUNDED_WSTRING)) {
        $rv = "CORBA.C_Types.Free_WString";
    } elsif (is_a($type, $CORBA::IDLtree::ANY)) {
        $rv = "CORBA.C_Types.Free_Any";
    } elsif (is_a($type, $CORBA::IDLtree::SEQUENCE)) {
        $rv = "CORBA.C_Types.C_Free";
    } elsif (pass_by_reference $type) {
        $rv = helper_prefix($type) . ".C_Free";
    }
    $rv;
}


sub dupproc {
    my $type = shift;
    my $rv = "";
    if (is_a($type, $CORBA::IDLtree::ANY)) {
        $rv = "CORBA.C_Types.C_Dup";
    } elsif (is_a($type, $CORBA::IDLtree::SEQUENCE)) {
        $rv = "CORBA.C_Types.C_Dup";
    } elsif (pass_by_reference $type) {
        $rv = helper_prefix($type) . ".C_Dup";
    }
    $rv;
}


sub gen_helper_ops {
    my $typeref = shift;
    if (not isnode $typeref or not pass_by_reference $typeref or
        is_a($typeref, $CORBA::IDLtree::SEQUENCE) or
        is_a($typeref, $CORBA::IDLtree::EXCEPTION)) {
        return;
    }
    my @node = @{$typeref};
    my $name = $node[$NAME];
    my $ptrtype = "C_${name}_Access";
    my $ctype = (is_complex($typeref) ? "C_$name" : $name);
    phspec "type $ptrtype is access all $ctype;\n\n";
    my $cprefix = prefix($typeref, $GEN_C_TYPE);
    phspec "function C_${name}_Alloc return $ptrtype;\n";
    phspec "pragma Import (C, C_${name}_Alloc,\n";
    phspec "               \"${cprefix}${name}__alloc\");\n\n";
    phboth "function C_Dup (Item : $ctype)";
    ehboth " return $ptrtype";
    ehspec ";\n\n";
    ehbody " is\n";
    phbody "   CTemp_Returns : $ptrtype := C_${name}_Alloc;\n";
    phbody "begin\n";
    phbody "   CTemp_Returns.all := Item;\n";
    phbody "   return CTemp_Returns;\n";
    phbody "end C_Dup;\n\n";
    phspec "procedure C_Free (Item : $ptrtype);\n";
    phspec "pragma Import (C, C_Free, \"CORBA_free\");\n\n";
}


sub gen_typecode_and_anycnv {
    if (not $gen_tc_any) {
        return;
    }
    my $typenode = shift;
    if (not isnode $typenode) {
        die "param to gen_typecode_and_anycnv is not node ($typenode)\n";
    }
    my $name = $$typenode[$NAME];
    my $adatype = mapped_type($typenode);
    my $ctype = c_var_type($typenode);
    my $cptrtype = helper_prefix($typenode) . ".C_${name}_Access";
    my $tcname = "TC_$name";
    my $is_interface = ($$typenode[$TYPE] == $CORBA::IDLtree::INTERFACE);
    my $is_sequence = is_a($typenode, $CORBA::IDLtree::SEQUENCE);
    my $is_simple = (CORBA::IDLtree::is_elementary_type($typenode, 1) ||
                     is_a($typenode, $CORBA::IDLtree::BOUNDED_STRING) ||
                     is_a($typenode, $CORBA::IDLtree::ENUM));
    my $cname = "TC_" . prefix($typenode, $GEN_C_TYPE) . $name;
    my $inner;
    if ($target_system == $ORBIT) {
        phbody "$tcname\_struct : CORBA.C_Types.C_TypeCode_struct;\n";
        phbody "pragma Import (C, $tcname\_struct, \"$cname\_struct\");\n";
        $inner = "CORBA.TypeCode.Address_To_TC ($tcname\_struct\'Address)";
    } elsif ($target_system == $CORBAWARE) {
        $inner = "$cname\_constant";
        phbody "$inner : CORBA.TypeCode.Object;\n";
        if ($is_interface) {
            $cname = "CORBA_TC_Object";   # workaround for CW-idl
        }
        phbody "pragma Import (C, $inner, \"$cname\");\n";
    }
    ehbody "\n";
    phboth "function $tcname return CORBA.TypeCode.Object";
    ehspec ";\n";
    ehbody " is\n";
    phbody "begin\n";
    phbody "   return $inner;\n";
    phbody "end $tcname;\n";
    ehbody "\n";
    phboth "function From_Any (From : CORBA.Any) return $adatype";
    ehspec ";\n";
    ehbody " is\n";
    if ($is_sequence) {
        phbody "   CTemp : CORBA.C_Types.C_Sequence_Access;\n";
    } elsif ($is_simple) {
        phbody "   package Convert is new\n";
        phbody "      System.Address_To_Access_Conversions ($ctype);\n";
        phbody "   CTemp : Convert.Object_Pointer;\n";
    } elsif (! $is_interface) {
        phbody "   function To_Pointer is new Unchecked_Conversion\n";
        phbody "     (System.Address, $cptrtype);\n";
        phbody "   CTemp : $cptrtype;\n";
    }
    phbody "   To : $adatype;\n";
    phbody "begin\n";
    $indentlvl[$#indentlvl]++;
    phbody "if not CORBA.TypeCode.Equal ($tcname,\n";
    phbody "                             CORBA.C_Types.Get_Type (From)) then\n";
    phbody "   raise CORBA.Bad_Typecode;\n";
    phbody "end if;\n";
    if ($is_interface) {
        phbody set_c_ref("To", "CORBA.C_Types.Get_Value (From)");
    } else {
        phbody "CTemp := ";
        ehbody("Convert.") if ($is_simple);
        if ($is_sequence) {
            ehbody "CORBA.C_Types.To_Seq_Access";
        } else {
            ehbody "To_Pointer";
        }
        ehbody " (CORBA.C_Types.Get_Value (From));\n";
        phbody c2ada("To", "CTemp.all", $typenode);
    }
    phbody "return To;\n";
    $indentlvl[$#indentlvl]--;
    phbody "end From_Any;\n";
    ehbody "\n";
    phboth "function To_Any (From : $adatype) return CORBA.Any";
    ehspec ";\n\n";
    ehbody " is\n";
    if ($is_sequence) {
        phbody "   CTemp : CORBA.C_Types.C_Sequence_Access;\n";
    } elsif ($is_simple) {
        phbody "   package Convert is new\n";
        phbody "      System.Address_To_Access_Conversions ($ctype);\n";
        phbody "   CTemp : Convert.Object_Pointer := new $ctype;\n";
    } elsif (! $is_interface) {
        phbody "   CTemp : $cptrtype;\n";
    }
    phbody "   Result : CORBA.Any;\n";
    phbody "begin\n";
    $indentlvl[$#indentlvl]++;
    my $cnv = ada2c("From", $typenode);
    if ($is_simple) {
        phbody "CTemp.all := $cnv;\n";
        $cnv = "Convert.To_Address (CTemp)";
    } elsif (! $is_interface) {
        phbody("CTemp := " . dupproc($typenode) . " ($cnv);\n");
        $cnv = "CTemp.all'Address";
    }
    phbody "CORBA.C_Types.Set_Type (Result, $tcname);\n";
    phbody "CORBA.C_Types.Set_Value (Result, $cnv);\n";
    phbody "return Result;\n";
    $indentlvl[$#indentlvl]--;
    phbody "end To_Any;\n";
    ehbody "\n";
}


sub do_method {
    my $symroot = shift;
    my $name = shift;
    my $argref = shift;
    my @exc_list = ();
    my $attr_prefix = "";
    my $adaname = $name;
    if (@_) {
        my $optpar = shift;
        if (ref $optpar) {
            # $optpar contains the exception list
            @exc_list = @{$optpar};
        } else {
            # $optpar contains the prefix of the attribute's Ada name
            # (Get_ or Set_)
            $attr_prefix = $optpar;
            $adaname = $attr_prefix . $name;
        }
    }
    my @arg = @{$argref};

    # Exception method
    my $i;
    if (@exc_list) {
        ppbody "procedure Raise_$name\_Exception";
        epbody " (Env : in CORBA.Environment.Object) is\n";
        ppbody "   use type CORBA.Exception_Type;\n";
        ppbody "   use type CORBA.String;\n";
        ppbody "   Id : CORBA.String;\n";
        ppbody "begin\n";
        $indentlvl[$#indentlvl]++;
        ppbody "if CORBA.Environment.Get_Exception_Type (Env) /=";
        epbody " CORBA.User_Exception then\n";
        ppbody "   return;\n";
        ppbody "end if;\n";
        ppbody "Id := CORBA.Environment.Exception_Id (Env);\n";
        foreach $exref (@exc_list) {
            my @exnode = @{$exref};
            my $exname = $exnode[$NAME];
            ppbody "if Id = $exname\_ExceptionName then\n";
            $indentlvl[$#indentlvl]++;
            my @components = @{$exnode[$SUBORDINATES]};
            if (@components) {
                my $lhs = "CORBA.Environment.Exception_Value (Env)";
                my $cplx = is_complex($exref);
                if ($cplx) {
                    my $hlp = helper_prefix($exref);
                    $lhs = "$hlp.To_Ada\n         "
                           . " ($hlp.Cnv_C_$exname\_Members.To_Pointer\n"
                           . "              ($lhs).all)";
                } else {
                    $lhs = "Cnv_$exname\_Members.To_Pointer\n"
                           . "              ($lhs).all";
                }
                ppbody "$exname\_ExceptionObject :=\n";
                ppbody "   $lhs;\n";
            }
            ppbody "CORBA.Environment.Raise_Exception\n";
            ppbody "   ($exname\'Identity,";
            epbody " $exname\_ExceptionObject\'Address);\n";
            $indentlvl[$#indentlvl]--;
            ppbody "end if;\n";
        }
        ppbody "raise CORBA.Unknown;\n";
        $indentlvl[$#indentlvl]--;
        ppbody "end Raise_$name\_Exception;\n\n";
    }
    # The Actual Method
    my $rettype = shift @arg;
    if ($rettype == $CORBA::IDLtree::ONEWAY) {
        ppispec "-- oneway\n";
        $rettype = $CORBA::IDLtree::VOID;
    }
    my $add_return_param = 0;
    if ($rettype == $CORBA::IDLtree::VOID) {
        pall "procedure ";
    } else {
        if (is_objref $rettype) {
            $add_return_param = $rettype;
            $rettype = $CORBA::IDLtree::VOID;
        } else {
            foreach $pnode (@arg) {
                my $pmode = $$pnode[$MODE];
                if ($pmode != $CORBA::IDLtree::IN) {
                    $add_return_param = $rettype;
                    $rettype = $CORBA::IDLtree::VOID;
                    last;
                }
            }
        }
        if ($add_return_param) {
            pall "procedure ";
        } else {
            pall "function  ";
        }
    }
    eall sprintf("%-12s (Self : ", $adaname);
    epboth "in Ref";
    eiboth "access Object";
    eospec "access Object";
    $indentlvl[$#indentlvl] += $INDENT2;
    if ($#arg >= 0 || $add_return_param) {
        for ($i = 0; $i <= $#arg; $i++) {
            my @pn = @{$arg[$i]};
            eall ";\n";
            pall subprog_param_text($pn[$TYPE], $pn[$NAME], $pn[$MODE]);
        }
        if ($add_return_param) {
            eall(";\n");
            pall("Returns : out " . mapped_type($add_return_param));
            eall("\'Class") if (is_objref $add_return_param);
        }
    }
    eall ")";
    if ($rettype != $CORBA::IDLtree::VOID) {
        eall "\n";
        pall("return " . mapped_type($rettype));
    }
    epispec  ";\n";
    $indentlvl[$#indentlvl] -= $INDENT2;
    if (@exc_list) {
        ppispec "-- raises (";
        foreach $exc (@exc_list) {
            epispec(${$exc}[$NAME] . " ");
        }
        epispec ")\n";
    }
    eispec "\n";
    epibody " is\n";
    eospec " is abstract;\n\n";

    ######################## Proxy body, POA specbuf, POA body outputs
    $poaspecbuf_enabled = 2;
    if ($add_return_param) {     # restore original rettype if necessary
        $rettype = $add_return_param;
    }
    if ($rettype == $CORBA::IDLtree::VOID) {
        ppobody "procedure ";
    } else {
        ppobody "function  ";
    }
    epobody(sprintf "C_%-12s (This : in ", $adaname);
    if ($target_system == $TAO) {
        epobody "CPP_Object;\n";
    } else {
        epobody "System.Address;\n";
    }
    $indentlvl[$#indentlvl] += $INDENT2 + 1;
    my $i;
    if (@arg) {
        for ($i = 0; $i <= $#arg; $i++) {
            my @pnode = @{$arg[$i]};
            ppobody subprog_param_text($pnode[$TYPE], $pnode[$NAME],
                                       $pnode[$MODE], $GEN_C_TYPE);
            epobody ";\n";
        }
    }
    ppobody "Env : access CORBA.Environment.Object)";
    if ($rettype != $CORBA::IDLtree::VOID) {
        epobody "\n";
        ppobody("return " . c_var_type($rettype, 1));
    }
    epbody ";\n";
    $poaspecbuf_enabled = 1;
    eospecbuf ";\n";
    eobody " is\n";
    $indentlvl[$#indentlvl] -= $INDENT2;
    if ($target_system == $TAO) {
        ppbody "pragma Import (CPP, C_$adaname, \"$adaname\", Link_Name =>\n";
        ppbody('  "' . mangled_name($name, \@arg, $$symroot[$SCOPEREF]));
        epbody "\");\n";
        pospecbuf "pragma CPP_Virtual (C_$adaname);\n\n";
    } else {
        my $prefix = prefix($symroot, $GEN_C_TYPE);
        ppbody "pragma Import (C, C_$adaname, \"";
        if ($target_system == $CORBAWARE) {
            epbody "Invoke_";
        }
        my $n = ($attr_prefix ? "_" . lcfirst($adaname) : $adaname);
        epbody "$prefix$n\");\n";
        if ($target_system == $CORBAWARE) {
            pospecbuf "pragma Export (C, C_$adaname, \"$prefix$n\");\n\n";
        } else {
            pospecbuf "pragma Convention (C, C_$adaname);\n\n";
        }
        if ($attr_prefix && $file_convention == $GNAT) {
            ppspec "pragma Export (C, $adaname, \"$prefix$adaname\");\n";
            ppspec "-- avoid conflict with C name\n";
        }
    }
    epspec "\n";
    ######################## Proxy body-only output
    for ($i = 0; $i <= $#arg; $i++) {
        my @pn = @{$arg[$i]};
        make_c_interfacing_var($pn[$TYPE], $pn[$NAME], $pn[$MODE]);
    }
    ppbody "Env : aliased CORBA.Environment.Object";
    if ($target_system == $CORBAWARE) {
        epbody " := CORBA.Basic_Object.Get_C_Env (Self)";
    }
    epbody ";\n";
    if ($rettype != $CORBA::IDLtree::VOID) {
        make_c_interfacing_var($rettype, "Returns", $CORBA::IDLtree::OUT,
                               $add_return_param);
    }
    $indentlvl[$#indentlvl]--;
    ppbody "begin\n";
    $indentlvl[$#indentlvl]++;
    for ($i = 0; $i <= $#arg; $i++) {
        my @pn = @{$arg[$i]};
        c_from_ada_var($pn[$TYPE], $pn[$NAME], $pn[$MODE], 1);
    }
    ppbody "";
    if ($rettype != $CORBA::IDLtree::VOID) {
        epbody(c_var_name($rettype, "Returns", $CORBA::IDLtree::OUT) .
               " := ");
    }
    epbody("C_$adaname (" . get_c_ref("Self") . ",\n");
    $indentlvl[$#indentlvl] += $INDENT2 - 1;
    if ($#arg >= 0) {
        for ($i = 0; $i <= $#arg; $i++) {
            my $pnode = $arg[$i];
            my $ptype = $$pnode[$TYPE];
            my $pname = $$pnode[$NAME];
            ppbody(c_var_name($ptype, $pname, $$pnode[$MODE]));
            if ($$pnode[$MODE] != $CORBA::IDLtree::IN ||
                is_a($ptype, $CORBA::IDLtree::ANY)) {
                epbody "'access";
            }
            epbody ",\n";
        }
    }
    ppbody "Env'access);\n";
    $indentlvl[$#indentlvl] -= $INDENT2 - 1;
    ppbody "CORBA.Environment.Raise_System_Exception (Env);\n";
    if (@exc_list) {
        ppbody "Raise_$name\_Exception (Env);\n";
    }
    for ($i = 0; $i <= $#arg; $i++) {
        my @pnode = @{$arg[$i]};
        ada_from_c_var($pnode[$TYPE], $pnode[$NAME], $pnode[$MODE]);
    }
    if ($rettype != $CORBA::IDLtree::VOID) {
        ada_from_c_var($rettype, "Returns", $CORBA::IDLtree::OUT);
        if (! $add_return_param) {
            ppbody "return Returns;\n";
        }
    }
    $indentlvl[$#indentlvl]--;
    ppbody "end $adaname;\n\n";
    $indentlvl[$#indentlvl]++;
    ######################## POA body-only output
    for ($i = 0; $i <= $#arg; $i++) {
        my @pnode = @{$arg[$i]};
        make_ada_interfacing_var($pnode[$TYPE], $pnode[$NAME]);
    }
    if ($rettype != $CORBA::IDLtree::VOID) {
        make_ada_interfacing_var($rettype, "Returns");
        pobody("Returns : " . c_var_type($rettype) . ";\n");
    }
    pobody_beginmethod;
    for ($i = 0; $i <= $#arg; $i++) {
        my @pn = @{$arg[$i]};
        ada_from_c_var($pn[$TYPE], $pn[$NAME], $pn[$MODE], 1);
    }
    pobody "begin\n";
    $indentlvl[$#indentlvl]++;
    pobody "";
    if (! $add_return_param and $rettype != $CORBA::IDLtree::VOID) {
        eobody(ada_var_name($rettype, "Returns") . " := ");
    }
    eobody "Dispatch_$adaname (Self";
    $indentlvl[$#indentlvl] += $INDENT2 - 1;
    for ($i = 0; $i <= $#arg; $i++) {
        my @pnode = @{$arg[$i]};
        eobody ",\n";
        pobody ada_var_name($pnode[$TYPE], $pnode[$NAME]);
        if ($pnode[$MODE] != $CORBA::IDLtree::IN &&
            ! is_complex($pnode[$TYPE])) {
            eobody ".all";
        }
    }
    if ($add_return_param) {
        eobody(", " . ada_var_name($rettype, "Returns"));
    }
    eobody ");\n";
    $indentlvl[$#indentlvl] -= $INDENT2 - 1;
    $indentlvl[$#indentlvl]--;
    pobody "exception\n";
    $indentlvl[$#indentlvl]++;
    foreach $exref (@exc_list) {
        my @exnode = @{$exref};
        my $exname = $exnode[$NAME];
        pobody "when E : $exname =>\n";
        $indentlvl[$#indentlvl]++;
        pobody "declare\n";
        $indentlvl[$#indentlvl]++;
        my $memtype = "$exname\_Members";
        pobody "AdaTemp_$exname : Cnv_$memtype.Object_Pointer :=\n";
        pobody "   Cnv_$memtype.To_Pointer\n";
        pobody "      (CORBA.Environment.Exception_Members_Address (E));\n";
        my $hlppkg = helper_prefix($exref);
        if (is_complex $exref) {
            pobody("CTemp_$exname : $hlppkg.Cnv_C_$memtype" .
                   ".Object_Pointer;\n");
            my $cprefix = $hlppkg;
            $cprefix =~ s/.Helper$//;
            $cprefix =~ s/\./_/g;
            pobody("function $exname\_Alloc return" .
                   " $hlppkg.Cnv_C_$memtype.Object_Pointer;\n");
            pobody("pragma Import (C, $exname\_Alloc," .
                   " \"$cprefix\_$exname\__alloc\");\n");
        }
        $indentlvl[$#indentlvl]--;
        pobody "begin\n";
        $indentlvl[$#indentlvl]++;
        my $cnv;
        if (is_complex $exref) {
            pobody "CTemp_$exname := $exname\_Alloc;\n";
            pobody("CTemp_$exname.all := $hlppkg.To_C " .
                   "(AdaTemp_$exname.all);\n");
            $cnv = "$hlppkg.Cnv_C_$memtype.To_Address (CTemp_$exname)";
        } else {
            $cnv = "Cnv_$memtype.To_Address (AdaTemp_$exname)";
        }
        if ($target_system == $CORBAWARE) {
            pobody "CORBA.BOA.Set_Exception\n";
            pobody "  (Self   => CORBA.BOA.Get_Default_BOA,\n";
            pobody "   Obj    => Self.all,\n";
            pobody "   Major  => CORBA.USER_EXCEPTION,\n";
            pobody "   Userid => ${exname}_ExceptionName,\n";
            pobody "   Param  => $cnv);\n";
        } else {
            pobody "CORBA.Environment.Set_User_Exception\n";
            pobody "  (Env, ${exname}_ExceptionName,\n";
            pobody "   $cnv);\n";
        }
        $indentlvl[$#indentlvl]--;
        pobody "end;\n\n";
        $indentlvl[$#indentlvl]--;
    }
    pobody "when others =>\n";
    pobody "   CORBA.Environment.Set_System_Exception\n";
    pobody "                        (Env, CORBA.Environment.UNKNOWN);\n";
    $indentlvl[$#indentlvl]--;
    pobody "end;\n";
    for ($i = 0; $i <= $#arg; $i++) {
        my @pn = @{$arg[$i]};
        c_from_ada_var($pn[$TYPE], $pn[$NAME], $pn[$MODE]);
    }
    if ($rettype != $CORBA::IDLtree::VOID) {
        # $add_return_param : To Be Done
        c_from_ada_var($rettype, "Returns", $CORBA::IDLtree::OUT);
        pobody "return ";
        if (return_by_reference $rettype) {
            eobody(dupproc($rettype) . " (Returns);\n");
        } else {
            eobody "Returns;\n";
        }
    }
    $indentlvl[$#indentlvl]--;
    pobody "end C_$adaname;\n\n";
    ######################## POA dispatch method output
    $poaspecbuf_enabled = 2;
    if ($add_return_param || $rettype == $CORBA::IDLtree::VOID) {
        pobody "procedure ";
    } else {
        pobody "function  ";
    }
    eobody "Dispatch_$adaname (Self : in Object_Access";
    $indentlvl[$#indentlvl] += $INDENT2 + 1;
    for ($i = 0; $i <= $#arg; $i++) {
        my @pn = @{$arg[$i]};
        eobody ";\n";
        pobody subprog_param_text($pn[$TYPE], $pn[$NAME], $pn[$MODE]);
    }
    if ($add_return_param) {
        eobody ";\n";
        pobody subprog_param_text($rettype, "Returns",
                                  $CORBA::IDLtree::OUT);
    }
    eobody ")";
    if (! $add_return_param && $rettype != $CORBA::IDLtree::VOID) {
        eobody "\n";
        pobody("return " .  mapped_type($rettype));
    }
    $poaspecbuf_enabled = 1;
    eospecbuf ";\n\n";
    eobody " is\n";
    $indentlvl[$#indentlvl] -= $INDENT2 + 1;
    pobody "begin\n";
    $indentlvl[$#indentlvl]++;
    if (! $add_return_param && $rettype != $CORBA::IDLtree::VOID) {
        pobody "return ";
    } else {
        pobody "";
    }
    eobody "$adaname (Self";
    $indentlvl[$#indentlvl] += $INDENT2 + 1;
    for ($i = 0; $i <= $#arg; $i++) {
        my @pnode = @{$arg[$i]};
        eobody(", " . $pnode[$NAME]);
    }
    if ($add_return_param) {
        eobody ", Returns";
    }
    eobody ");\n";
    $indentlvl[$#indentlvl] -= $INDENT2 + 2;
    pobody "end Dispatch_$adaname;\n\n";
    $poaspecbuf_enabled = 0;
    $add_return_param;
}


sub gen_ada {
    my $symroot = shift;

    if (! $symroot) {
        print "\ngen_ada: encountered empty elem (returning)\n";
        return;
    } elsif (not ref $symroot) {
        print "\ngen_ada: incoming symroot is $symroot (returning)\n";
        return;
    }
    if (not isnode $symroot) {
        foreach $elem (@{$symroot}) {
            gen_ada $elem;
        }
        return;
    }
    my @node = @{$symroot};
    my $name = $node[$NAME];
    my $type = $node[$TYPE];
    my $subord = $node[$SUBORDINATES];
    my @arg = @{$subord};

    if ($type == $CORBA::IDLtree::TYPEDEF) {
        my $typeref = $arg[0];
        my $dimref = $arg[1];
        my $adatype = check_sequence($typeref);
        my $cplx = is_complex $typeref;
        if (isnode($typeref) && $$typeref[$TYPE] == $CORBA::IDLtree::FIXED) {
            my @digits_and_scale = $$typeref[$SUBORDINATES];
            my $digits = $digits_and_scale[0];
            my $delta = 10 ** -$digits_and_scale[1];
            ppspec "type $adatype is delta $delta digits $digits;\n";
        }
        my $sub = "";
        if (is_objref($typeref) && ! scalar(@{$dimref})) {
            $sub = "sub";
        }
        ppspec "${sub}type $name is ";
        my $is_array = ($dimref && scalar(@{$dimref}));
        my $ctype = c_var_type($typeref);
        if ($is_array) {
            epspec "array (";
            my $is_first_dim = 1;
            ehspec("   type C_$name is array (") if ($cplx);
            foreach $dim (@{$dimref}) {
                my $range = array_range($dim);
                if ($is_first_dim) {
                    $is_first_dim = 0;
                } else {
                    epspec ", ";
                    ehspec(", ") if ($cplx);
                }
                epspec $range;
                ehspec($range) if ($cplx);
            }
            epspec ") of ";
            ehspec(") of ") if ($cplx);
        } else {
            epspec("new ") unless ($sub);
        }
        epspec "$adatype;\n";
        my $c_basetype = c_var_type($typeref);
        if ($is_array) {
            if ($cplx) {
                ehspec "$c_basetype;\n";
                phspec "pragma Convention (C, C_$name);\n\n";
                phboth "function To_C (From : $name) return C_$name";
                ehspec ";\n";
                ehbody " is\n";
                phbody "   To : C_$name;\n";
                phbody "begin\n";
                my $i;
                my @dims = @{$dimref};
                my $idxs = "";
                for ($i = 0; $i <= $#dims; $i++) {
                    my $range = array_range($dims[$i]);
                    $indentlvl[$#indentlvl]++;
                    phbody "for I$i in $range loop\n";
                    if ($i > 0) {
                        $idxs .= ", ";
                    }
                    $idxs .= "I$i";
                }
                $indentlvl[$#indentlvl]++;
                phbody "To ($idxs) := ";
                ehbody ada2c("From ($idxs)", $typeref);
                ehbody ";\n";
                for ($i = 0; $i <= $#dims; $i++) {
                    $indentlvl[$#indentlvl]--;
                    phbody "end loop;\n";
                }
                phbody "return To;\n";
                $indentlvl[$#indentlvl]--;
                phbody "end To_C;\n\n";
                phboth "function To_Ada (From : C_$name) return $name";
                ehspec ";\n\n";
                ehbody " is\n";
                phbody "   To : $name;\n";
                phbody "begin\n";
                for ($i = 0; $i <= $#dims; $i++) {
                    my $range = array_range($dims[$i]);
                    $indentlvl[$#indentlvl]++;
                    phbody "for I$i in $range loop\n";
                }
                $indentlvl[$#indentlvl]++;
                phbody c2ada("To ($idxs)", "From ($idxs)", $typeref);
                for ($i = 0; $i <= $#dims; $i++) {
                    $indentlvl[$#indentlvl]--;
                    phbody "end loop;\n";
                }
                phbody "return To;\n";
                $indentlvl[$#indentlvl]--;
                phbody "end To_Ada;\n\n";
            } else {
                ppspec "pragma Convention (C, $name);\n";
            }
        } elsif ($cplx != 0 && $cplx != $CORBA::IDLtree::BOUNDED_STRING) {
            # N.B. C/Ada conv. for bounded strings is in sub check_sequence
            phboth "function To_C (From : $name) return $c_basetype";
            ehspec ";\n";
            ehbody " is\n";
            phbody "   To : $adatype;\n";
            phbody "begin\n";
            $indentlvl[$#indentlvl]++;
            phbody "To := $adatype (From);\n";
            phbody("return " . ada2c("To", $typeref) . ";\n");
            $indentlvl[$#indentlvl]--;
            phbody "end To_C;\n\n";
            phboth "function To_Ada (From : $c_basetype) return $name";
            ehspec ";\n\n";
            ehbody " is\n";
            phbody "   To : $adatype;\n";
            phbody "begin\n";
            $indentlvl[$#indentlvl]++;
            phbody c2ada("To", "From", $typeref);
            phbody "return $name (To);\n";
            $indentlvl[$#indentlvl]--;
            phbody "end To_Ada;\n\n";
        }
        epspec "\n";
        gen_typecode_and_anycnv $symroot;
        gen_helper_ops $symroot;

    } elsif ($type == $CORBA::IDLtree::CONST) {
        my $adatype = mapped_type($arg[0]);
        my $rhs = const2ada($arg[0], cvt_expr($arg[1]));
        ppspec "$name : constant $adatype := $rhs;\n\n";

    } elsif ($type == $CORBA::IDLtree::ENUM) {
        ppspec("type $name is ");
        my $enum_literals = join(', ', @arg);
        if (length($name) + length($enum_literals) < 65) {
            epspec "($enum_literals);\n";
        } else {
            epspec "\n";
            my $first = 1;
            $indentlvl[$#indentlvl] += $INDENT2 - 1;
            foreach $lit (@arg) {
                if ($first) {
                    ppspec "  ($lit";
                    $indentlvl[$#indentlvl]++;
                    $first = 0;
                } else {
                    epspec ",\n";
                    ppspec $lit;
                }
            }
            epspec ");\n";
            $indentlvl[$#indentlvl] -= $INDENT2;
        }
        if ($file_convention == $APEX) {
            ppspec "for $name\'Size use 32;\n\n";
        } else {
            ppspec "pragma Convention (C, $name);\n\n";
        }
        gen_typecode_and_anycnv $symroot;

    } elsif ($type == $CORBA::IDLtree::STRUCT ||
             $type == $CORBA::IDLtree::UNION ||
             $type == $CORBA::IDLtree::EXCEPTION) {
        my $is_union = ($type == $CORBA::IDLtree::UNION);
        my $need_help = is_complex($symroot, $ANALYZE_UNION);
        my @adatype = ();
        my $i = ($is_union) ? 1 : 0;
        # First, generate array and sequence type declarations if necessary
        for (; $i <= $#arg; $i++) {
            my @node = @{$arg[$i]};
            my $t = $node[$TYPE];
            next if ($t == $CORBA::IDLtree::CASE or
                     $t == $CORBA::IDLtree::DEFAULT);
            push @adatype, check_sequence($t);
            my $dimref = $node[$SUBORDINATES];
            if ($dimref and @{$dimref}) {
                my $name = $node[$NAME];
                ppspec("type " . $name . "_Array is array (");
                my $is_first_dim = 1;
                foreach $dim (@{$dimref}) {
                    if ($dim !~ /\D/) {   # if the dim is a number
                        $dim--;           # then modify that number directly
                    } else {
                        $dim .= " - 1" ;  # else leave it to the Ada compiler
                    }
                    if ($is_first_dim) {
                        $is_first_dim = 0;
                    } else {
                        epspec ", ";
                    }
                    epspec("0.." . $dim);
                }
                epspec(") of " . $adatype[$#adatype] . ";\n\n");
            }
        }
        # Now comes the actual struct/union/exception
        my $need_end_record = 1;
        my $typename = $name;
        if ($type == $CORBA::IDLtree::EXCEPTION) {
            ppspec "$name : exception;\n\n";
            $typename .= "_Members";
            ppspec "type $typename is new CORBA.IDL_Exception_Members ";
            if (@arg) {
                epspec "with record\n";
            } else {
                epspec "with null record;\n\n";
                $need_end_record = 0;
            }
        } else {
            ppspec "type $name ";
            if ($is_union) {
                my $adatype = mapped_type($arg[0]);
                epspec "(Switch : $adatype := $adatype\'First) ";
            }
            epspec "is record\n";
            if ($is_union) {
                $indentlvl[$#indentlvl]++;
                ppspec "case Switch is\n";
            }
        }
        if ($need_help && scalar(@arg)) {
            if ($is_union) {
                my $dtype = c_var_type($arg[0]);
                $indentlvl[$#indentlvl]--;
                phspec "type Wrapped_$typename ";
                ehspec "(Switch : $dtype := $dtype\'First) is record\n";
                $indentlvl[$#indentlvl]++;
                phspec "case Switch is\n";
            } else {
                phspec "type C_$typename is record\n";
            }
        }
        if ($need_end_record) {
            my $had_case = 0;
            my $had_default = 0;
            my $n_cases = 0;
            $indentlvl[$#indentlvl]++;
            for ($i = ($is_union) ? 1 : 0; $i <= $#arg; $i++) {
                my @node = @{$arg[$i]};
                my $name = $node[$NAME];
                my $t = $node[$TYPE];
                my $suboref = $node[$SUBORDINATES];
                if ($t == $CORBA::IDLtree::CASE or
                    $t == $CORBA::IDLtree::DEFAULT) {
                    if ($had_case) {
                        $indentlvl[$#indentlvl]--;
                    } else {
                        $had_case = 1;
                    }
                    if ($t == $CORBA::IDLtree::CASE) {
                        ppspec "when ";
                        phspec("when ") if ($need_help);
                        my $first_case = 1;
                        foreach $case (@{$suboref}) {
                            if ($first_case) {
                                $first_case = 0;
                            } else {
                                epspec "| ";
                                ehspec("| ") if ($need_help);
                            }
                            epspec "$case ";
                            ehspec("$case ") if ($need_help);
                            $n_cases++;
                        }
                        epspec "=>\n";
                        ehspec("=>\n") if ($need_help);
                    } else {
                        ppspec "when others =>\n";
                        phspec("when others =>\n") if ($need_help);
                        $had_default = 1;
                    }
                    $indentlvl[$#indentlvl]++;
                } else {
                    ppspec("$name : " . shift(@adatype) . ";\n");
                    if ($need_help) {
                        phspec("$name : " . c_var_type($t) . ";\n");
                    }
                }
            }
            my $need_default = 0;
            if ($is_union) {
                if (! $had_default) {
                    if (is_integer_type $arg[0]) {
                        $need_default = 1;
                    } else {
                        my @enumnode = @{$arg[0]};
                        if ($n_cases < scalar(@{$enumnode[$SUBORDINATES]})) {
                            $need_default = 1;
                        }
                    }
                    if ($need_default) {
                        $indentlvl[$#indentlvl]--;
                        ppspec "when others =>\n";
                        phspec("when others =>\n") if ($need_help);
                        $indentlvl[$#indentlvl]++;
                        ppspec "null;\n";
                        phspec("null;\n") if ($need_help);
                    }
                }
                $indentlvl[$#indentlvl] -= 2;
                ppspec "end case;\n";
                phspec("end case;\n") if ($need_help);
            }
            $indentlvl[$#indentlvl]--;
            ppspec "end record;\n";
            if ($need_help && scalar(@arg)) {
                epspec "\n";
                phspec "end record;\n";
            }
            if ($is_union) {
                my $wrapped = "";
                if ($need_help) {
                    phspec "pragma Convention (C, Wrapped_$typename);\n\n";
                    $wrapped = "Wrapped_";
                }
                my $dtype = c_var_type($arg[0]);
                phspec "type C_$typename is record\n";
                phspec "   Wrapped : $wrapped$typename;\n";
                phspec "end record;\n";
            }
            if ($need_help && scalar(@arg)) {
                phspec "pragma Convention (C, C_$typename);\n\n";
                phboth "function To_C (From : $typename) return C_$typename";
                ehspec ";\n";
                ehbody " is\n";
                phbody "   To : C_$typename;\n";
                if ($is_union) {
                    phbody "   Inner : Wrapped_$typename (From.Switch);\n";
                }
                phbody "begin\n";
                $indentlvl[$#indentlvl]++;
                if ($is_union) {
                    phbody "case From.Switch is\n";
                    for ($i = 1; $i <= $#arg; $i++) {
                        my @node = @{$arg[$i]};
                        my $name = $node[$NAME];
                        my $t = $node[$TYPE];
                        my $suboref = $node[$SUBORDINATES];
                        if ($t == $CORBA::IDLtree::CASE) {
                            my $first = 1;
                            phbody "   when ";
                            foreach $case (@{$suboref}) {
                                if ($first) {
                                    $first = 0;
                                } else {
                                    ehbody "| ";
                                }
                                ehbody "$case ";
                            }
                            ehbody "=>\n";
                            # find the component type for these cases
                            my $j;
                            my $cnv;
                            for ($j = $i + 1; $j <= $#arg; $j++) {
                                @node = @{$arg[$j]};
                                my $nm = $node[$NAME];
                                $t = $node[$TYPE];
                                if ($t != $CORBA::IDLtree::CASE) {
                                    $cnv = ada2c ("From.$nm", $t);
                                    last;
                                }
                            }
                            phbody "      Inner.$node[$NAME] := $cnv;\n";
                        } elsif ($t == $CORBA::IDLtree::DEFAULT) {
                            phbody "   when others =>\n";
                            @node = @{$arg[$i + 1]};
                            my $cnv = ada2c("From." . $node[$NAME],
                                                $node[$TYPE]);
                            phbody "      Inner.$node[$NAME] := $cnv;\n";
                            last;
                        }
                    }
                    if ($need_default) {
                        phbody "  when others =>\n";
                        phbody "     null;\n";
                    }
                    phbody "end case;\n";
                    phbody "To.Wrapped := Inner;\n";
                } else {
                    for ($i = 0; $i <= $#arg; $i++) {
                        my @node = @{$arg[$i]};
                        my $name = $node[$NAME];
                        my $cnv;
                        $cnv = ada2c("From.$name", $node[$TYPE]);
                        phbody "To.$name := $cnv;\n";
                    }
                }
                phbody "return To;\n";
                $indentlvl[$#indentlvl]--;
                phbody "end To_C;\n\n";
                phboth "function To_Ada (From : C_$typename) return $typename";
                ehspec ";\n";
                ehbody " is\n";
                phbody "   To : $typename";
                ehbody(" (From.Wrapped.Switch)") if ($is_union);
                ehbody ";\n";
                phbody "begin\n";
                $indentlvl[$#indentlvl]++;
                phbody("case From.Wrapped.Switch is\n") if ($is_union);
                for ($i = ($is_union) ? 1 : 0; $i <= $#arg; $i++) {
                    my @node = @{$arg[$i]};
                    my $name = $node[$NAME];
                    my $t = $node[$TYPE];
                    my $suboref = $node[$SUBORDINATES];
                    if ($t == $CORBA::IDLtree::CASE) {
                        phbody "   when ";
                        my $first = 1;
                        foreach $case (@{$suboref}) {
                            if ($first) {
                                $first = 0;
                            } else {
                                ehbody "| ";
                            }
                            ehbody "$case ";
                        }
                        ehbody "=>\n";
                    } elsif ($t == $CORBA::IDLtree::DEFAULT) {
                        phbody "   when others =>\n";
                    } else {
                        my $from = "From.";
                        if ($is_union) {
                            $from .= "Wrapped.";
                            ehbody "      ";
                        }
                        phbody c2ada("To.$name", "$from$name", $t);
                    }
                }
                if ($need_default) {
                    phbody "   when others =>\n";
                    phbody "      null;\n";
                }
                phbody("end case;\n") if ($is_union);
                phbody "return To;\n";
                $indentlvl[$#indentlvl]--;
                phbody "end To_Ada;\n\n";
                if ($type == $CORBA::IDLtree::EXCEPTION) {
                    phspec "package Cnv_C_$typename is new\n";
                    phspec "   System.Address_To_Access_Conversions";
                    ehspec " (C_$typename);\n\n";
                }
            } else {
                ehspec "\n";
                if ($type != $CORBA::IDLtree::EXCEPTION) {
                    ppspec "pragma Convention (C, $name);\n\n";
                }
            }
        }
        if ($type == $CORBA::IDLtree::EXCEPTION) {
            ppbody "$name\_ExceptionObject : $typename;\n";
            my $cexname = "IDL:$pragprefix" . join('/', @scopestack) . "/$name";
            $cexname .= ":1.0";
            ppobody "$name\_ExceptionName : constant CORBA.String :=\n";
            ppobody "   CORBA.To_CORBA_String (\"$cexname\");\n\n";
            ppobody "package Cnv_$typename is new";
            epobody " System.Address_To_Access_Conversions\n";
            ppobody "           ($typename);\n\n";
            #################### proxy side Get_Members method
            ppboth("procedure Get_Members (From : in " .
                  "Ada.Exceptions.Exception_Occurrence;\n");
            ppboth "                       To : out $typename)";
            epspec ";\n\n";
            epbody " is\n";
            ppbody "begin\n";
            $indentlvl[$#indentlvl]++;
            ppbody "To := Cnv_$typename.To_Pointer\n";
            $indentlvl[$#indentlvl] += 3;
            ppbody "(CORBA.Environment.Exception_Members_Address (From)).all;\n";
            $indentlvl[$#indentlvl] = 1;
            ppbody "end Get_Members;\n\n\n";
        } else {
            gen_typecode_and_anycnv $symroot;
        }
        gen_helper_ops $symroot;

    } elsif ($type == $CORBA::IDLtree::INCFILE) {
        $name =~ s/\.idl//i;
        $name =~ s@.*/@@;
        ppspec "with $name;\n";

    } elsif ($type == $CORBA::IDLtree::PRAGMA_PREFIX) {
        $pragprefix = $name . '/';

    } elsif ($type == $CORBA::IDLtree::PRAGMA_VERSION) {

    } elsif ($type == $CORBA::IDLtree::MODULE) {
        open_files($name, $type);
        my $adaname = join ".", @scopestack;
        print_pkg_decl $adaname;
        foreach $declaration (@arg) {
            gen_ada $declaration;
        }
        # generate proxy spec private part (if need be)
        epspec($specbuf) if ($specbuf);
        finish_pkg_decl $adaname;

    } elsif ($type == $CORBA::IDLtree::INTERFACE) {
        my $ancestor_ref = shift(@arg);
        foreach $iref (@{$ancestor_ref}) {
            my $ancname = lc($$iref[$NAME]);
            if (not exists $ancestors{$ancname}) {
                $ancestors{$ancname} = 1;
            }
        }
        open_files($name, $type);
        my $adaname = join ".", @scopestack;
        print_pkg_decl($adaname, 1);
        print_spec_interface_fixedparts($adaname, $ancestor_ref);
        print_body_interface_fixedparts($adaname, $ancestor_ref);
        print_ispec_interface_fixedparts($adaname, $ancestor_ref);
        print_ibody_interface_fixedparts $adaname;
        gen_typecode_and_anycnv $symroot;
        $poaspecbuf = "private\n\n";
        # For each attribute, a private member variable will be added
        # to the implementation object type.
        my @attributes = ();
        my @opnames = ();
        my $have_method = 0;
        foreach $decl (@arg) {
            gen_ada $decl;
            next unless (isnode($decl));
            my $type = ${$decl}[$TYPE];
            my $name = ${$decl}[$NAME];
            if ($type == $CORBA::IDLtree::ATTRIBUTE) {
                push @attributes, $decl;
                push @opnames, "Get_" . $name;
                my $arg = ${$decl}[$SUBORDINATES];
                my $readonly = $$arg[0];
                push(@opnames, "Set_" . $name) unless $readonly;
                $have_method = 1;
            } elsif ($type == $CORBA::IDLtree::METHOD) {
                push @opnames, $name;
                $have_method = 1;
            }
        }
        if (@{$ancestor_ref}) {
            my @further_ancestors = @{$ancestor_ref};
            shift @further_ancestors;  # discard first ancestor
            foreach $iref (@further_ancestors) {
                my @subord = @{$$iref[$SUBORDINATES]};
                my $name = $$iref[$NAME];
                ppispec "-- Methods inherited from $name\n\n";
                foreach $decl (@{$subord[1]}) {
                    my $type = ${$decl}[$TYPE];
                    if ($type == $CORBA::IDLtree::ATTRIBUTE ||
                        $type == $CORBA::IDLtree::METHOD) {
                        gen_ada $decl;
                    }
                }
            }
        }
        if ($gen_ispec[$#scopestack]) {
            eispec "private\n";
            pispec "type Object is new POA_$adaname.Object ";
            if (@attributes) {
                eispec "with record\n";
                $indentlvl[$#indentlvl]++;
                foreach $attr_ref (@attributes) {
                    my $name = ${$attr_ref}[$NAME];
                    my $subord = ${$attr_ref}[$SUBORDINATES];
                    my $typename = mapped_type(${$subord}[1]);
                    pispec "$name : $typename;";
                    eispec("   -- IDL: readonly") if (${$subord}[0]);
                    eispec "\n";
                }
                $indentlvl[$#indentlvl]--;
                pispec "end record;\n\n";
            } else {
                eispec "with null record;\n\n";
            }
        }
        if (exists $fwd_decl{$name}) {
            ppspec("package Convert is new " . prefix($fwd_decl{$name}) .
                   "$name\_Forward.Convert (Ref);\n\n");
        }
        if ($target_system == $ORBIT) {
            # ORBit specific POA function The_Epv (required for inheritance)
            pospec "-- ORBit specific:\n";
            poboth "function The_Epv return System.Address";
            eospec ";\n";
            pospec "pragma Inline (The_Epv);\n\n";
            eobody " is\n";
            pobody "begin\n";
            pobody "   return epv'address;\n";
            pobody "end The_Epv;\n\n";
        }
        # generate POA spec private part
        eospec $poaspecbuf;
        if ($target_system == $ORBIT) {
            pospec("N_Methods : constant := " . scalar(@opnames) .";\n\n");
            pospec "epv : aliased array (0..N_Methods) of System.Address\n";
            pospec "    := (System.Null_Address,\n";
            my $i;
            for ($i = 0; $i <= $#opnames; $i++) {
                pospec("        C_" . $opnames[$i] . "\'address");
                if ($i < $#opnames) {
                    eospec ",\n";
                } else {
                    eospec ");\n\n";
                }
            }
            pospec "ServantBase_epv : array (0..2) of System.Address\n";
            pospec "   := (others => System.Null_Address); -- TBC\n\n";
            my $n_ancestors = scalar(@{$ancestor_ref});
            pospec "Inherited_Interfaces : constant := $n_ancestors;\n\n";
            pospec("vepv : array (0..1+Inherited_Interfaces) "
                   . "of System.Address\n");
            pospec "   := (ServantBase_epv'address,\n";
            foreach $iface (@{$ancestor_ref}) {
                pospec("       POA_" . prefix($iface) . $$iface[$NAME] .
                       ".The_Epv,\n");
            }
            pospec "       epv'address);\n\n";
        }
        # generate proxy spec private part (if need be)
        espec($specbuf) if ($specbuf);
        finish_pkg_decl($adaname, 1);
        if (! $have_method) {
            unlink bodyfilename($adaname);
        }

    } elsif ($type == $CORBA::IDLtree::INTERFACE_FWD) {
        ppspec "package $name\_Forward is new CORBA.Forward;\n\n";
        $fwd_decl{$name} = $symroot;

    } elsif ($type == $CORBA::IDLtree::ATTRIBUTE) {
        my $readonly = shift(@arg);
        my $rettype = $arg[0];
        do_method($symroot, $name, \@arg, "Get_");
        # Impl body
        pibody "begin\n";
        pibody "   return Self.$name;\n";
        pibody "end Get_$name;\n\n";
        if ($readonly) {
            return;
        }
        my @pnode = ($rettype, "To", $CORBA::IDLtree::IN);
        $arg[0] = $CORBA::IDLtree::VOID;
        $arg[1] = \@pnode;
        do_method($symroot, $name, \@arg, "Set_");
        # Impl body
        pibody "begin\n";
        pibody  "   Self.$name := To;\n";
        pibody "end Set_$name;\n\n";

    } elsif ($type == $CORBA::IDLtree::METHOD) {
        my $exlistref = pop(@arg);
        my $add_return_param = do_method($symroot, $name, \@arg, $exlistref);
        # Impl body
        if ($gen_separates) {
            pibody "   separate;\n\n";
        } else {
            my $make_retvar = (! $add_return_param &&
                               $arg[0] != $CORBA::IDLtree::ONEWAY &&
                               $arg[0] != $CORBA::IDLtree::VOID);
            if ($make_retvar) {
                pibody("   Returns : " . mapped_type($arg[0]) . ";");
                eibody "  -- make the compiler happy\n";
            }
            pibody "begin\n";
            if ($make_retvar) {
                pibody "   return Returns;";
            } else {
                pibody "   null;";
            }
            eibody "  -- dear user, please fill me in\n";
            pibody "end $name;\n\n";
        }

    } else {
        print "gen_ada: unknown type value $type\n";
    }
}



sub check_helper {
    my $type = shift;
    if (is_complex($type) && !is_objref($type) &&
        $type != $CORBA::IDLtree::BOOLEAN &&
        $type != $CORBA::IDLtree::STRING &&
        $type != $CORBA::IDLtree::WSTRING &&
        $type != $CORBA::IDLtree::ANY) {
        my $helper_prefix = lc(prefix $type);
        $helper_prefix =~ s/\.$//;
        if (not exists $helpers{$helper_prefix}) {
            $helpers{$helper_prefix} = 1;
        }
    }
}


sub check_features_used {
    my $symroot = shift;
    my $scope = shift;
    my $inside_includefile = shift;
    if (not ref $symroot) {
        return;
    } elsif (not isnode $symroot) {
        foreach $node (@{$symroot}) {
            check_features_used($node, $scope, $inside_includefile);
        }
        return;
    }
    my @node = @{$symroot};
    if ($node[$TYPE] == $CORBA::IDLtree::MODULE ||
        $node[$TYPE] == $CORBA::IDLtree::INTERFACE) {
        if ($gen_tc_any) {
            my $pfx = prefix($symroot);
            my $helper_prefix = lc($pfx . $node[$NAME]);
            if (not exists $helpers{$helper_prefix}) {
                $helpers{$helper_prefix} = 1;
            }
        }
    } elsif ($node[$TYPE] == $CORBA::IDLtree::TYPEDEF) {
        my @origtype_and_dim = @{$node[$SUBORDINATES]};
        check_features_used($origtype_and_dim[0], $scope, $inside_includefile);
    } elsif ($node[$TYPE] == $CORBA::IDLtree::STRUCT ||
             $node[$TYPE] == $CORBA::IDLtree::EXCEPTION) {
        check_helper $symroot;
        if ($node[$TYPE] == $CORBA::IDLtree::EXCEPTION) {
            $need_exceptions = 1;
        }
        my @components = @{$node[$SUBORDINATES]};
        foreach $member (@components) {
            my $type = $$member[$TYPE];
            next if ($type == $CORBA::IDLtree::CASE ||
                     $type == $CORBA::IDLtree::DEFAULT);
            next if (is_objref $type);
            check_features_used ($type, $scope, $inside_includefile);
        }
    } elsif ($node[$TYPE] == $CORBA::IDLtree::UNION) {
        if (not exists $helpers{lc $scope}) {
            $helpers{lc $scope} = 1;
        }
    } elsif ($node[$TYPE] == $CORBA::IDLtree::SEQUENCE) {
        if ($node[$NAME]) {
            $need_bounded_seq = 1;
        } else {
            $need_unbounded_seq = 1;
        }
    } elsif ($node[$TYPE] == $CORBA::IDLtree::BOUNDED_STRING) {
        if (not exists $strbound{$node[$NAME]}) {
            my $bound = $node[$NAME];
            $strbound{$bound} = 1;
            my $filename = specfilename("corba", "bounded_string_${bound}");
            if (not -e $filename) {
                open(BSP, ">$filename") or die "cannot create $filename\n";
                print BSP "with CORBA.Bounded_Strings;\n\n";
                print BSP "package CORBA.Bounded_String_$bound is new";
                print BSP " CORBA.Bounded_Strings ($bound);\n\n";
                close BSP;
            }
        }
    } elsif ($node[$TYPE] == $CORBA::IDLtree::BOUNDED_WSTRING) {
        if (not exists $wstrbound{$node[$NAME]}) {
            my $bound = $node[$NAME];
            $wstrbound{$bound} = 1;
            my $filename = specfilename("corba", "bounded_wide_string_${bound}");
            if (not -e $filename) {
                open(BSP, ">$filename") or die "cannot create $filename\n";
                print BSP "with CORBA.Bounded_Wide_Strings;\n\n";
                print BSP "package CORBA.Bounded_Wide_String_$bound is new";
                print BSP " CORBA.Bounded_Wide_Strings ($bound);\n\n";
                close BSP;
            }
        }
    } elsif ($node[$TYPE] == $CORBA::IDLtree::ATTRIBUTE) {
        my @roflag_and_type = @{$node[$SUBORDINATES]};
        check_helper $roflag_and_type[1];
    } elsif ($node[$TYPE] == $CORBA::IDLtree::METHOD) {
        my @params = @{$node[$SUBORDINATES]};
        my $retvaltype = shift @params;
        check_helper($retvaltype, $node[$SUBORDINATES], $scope);
        pop @params;    # discard exception list
        if (scalar @params) {
            foreach $param_ref (@params) {
                my @param = @{$param_ref};
                check_helper $param[$TYPE];
            }
        }
    }
}

# The End.

