=head1 NAME

CGI::MultiValuedHash - Store and manipulate url-encoded data.

=cut

######################################################################

package CGI::MultiValuedHash;
require 5.004;

# Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION @ISA);
$VERSION = '1.05';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	Data::MultiValuedHash 1.05 (parent class)

=cut

######################################################################

use Data::MultiValuedHash 1.05;
@ISA = qw( Data::MultiValuedHash );

######################################################################

=head1 SYNOPSIS

	use CGI::MultiValuedHash;

	my $case_insensitive = 1;
	my $complementry_set = 1;

	my $params = CGI::MultiValuedHash->new( $case_insensitive, 
		$ENV{'HTTP_COOKIE'} || $ENV{'COOKIE'}, '; ', '&' );

	my $query_string = '';
	if( $ENV{'REQUEST_METHOD'} =~ /^(GET|HEAD)$/ ) {
		$query_string = $ENV{'QUERY_STRING'};
	} else {
		read( STDIN, $query_string, $ENV{'CONTENT_LENGTH'} );
	}
	$params->from_url_encoded_string( $query_string );
	$params->trim_bounding_whitespace();  # clean up user input

	foreach my $key ($params->keys()) {
		my @values = $params->fetch( $key );
		print "Field '$key' contains: '".join( "','", @values )."'\n";
	}

	my @record_list = ();

	open( FH, "+<guestbook.txt" ) or die "can't open file: $!\n";
	flock( FH, 2 );
	seek( FH, 0, 2 );
	$params->to_file( \*FH );
	seek( FH, 0, 0 );
	until( eof( FH ) ) {
		push( @record_list, CGI::MultiValuedHash->new( 
			$case_insensitive, \*FH ) );
	}
	flock( FH, 8 );
	close( FH );
		
	foreach my $record (@record_list) {
		print "\nSubmitted by:".$record->fetch_value( 'name' )."\n";
		print "\nTracking cookie:".$record->fetch_value( 'track' )."\n";
		my %Qs_and_As = $record->fetch_all( ['name', 'track'], $complementary_set );
		foreach my $key (keys %Qs_and_As) {
			my @values = @{$Qs_and_As{$key}};
			print "Question: '$key'\n";
			print "Answers: '".join( "','", @values )."'\n";
		}
	}

=head1 DESCRIPTION

This Perl 5 object class extends the functionality of Data::MultiValuedHash with
new methods that are especially useful in a CGI environment.  Please read the POD
for the latter to see what the preexisting features are.  New functionality
includes importing and exporting of url-encoded data.  This process is
customizable and can handle such formats as http query or cookie strings, or
newline-delimited text files.  Similarly, this class can import from or export to
a file stream.  Other new features include exporting to html-encoded hidden form
fields, for the purpose of having persistant form data that is too large for a
query string.  New manipulation features include trimming of whitespace from
values so that when users type only enter such the field reads as empty.  Useful
inherited features include optional case-insensitive keys and the ability to
export subsets of data when only some is needed (separate "other" form fields
from special ones that you previously used).

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_MAIN_HASH = 'main_hash';  # this is a hash of arrays
my $KEY_CASE_INSE = 'case_inse';  # are our keys case insensitive?

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using object notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.  If you are inheriting this class for
your own modules, then that often means something like B<$self-E<gt>method()>. 

This class is a subclass of Data::MultiValuedHash and inherits all of the
latter's functionality and behaviour.  Please read the POD for the latter to see
how to use the preexisting methods.

=head1 FUNCTIONS AND METHODS

=head2 initialize([ CASE[, SOURCE[, *]] ])

The above method in Data::MultiValuedHash has hooks which allow subclasses to 
add more data types to be used for SOURCE; the hook is called if SOURCE is not 
a Hash ref (normal or of arrays) or an MVH object, which are already handled.
This class adds the ability to use filehandles and url-encoded strings as SOURCE.
If SOURCE is a valid file handle then from_file( SOURCE, * ) is used.  Otherwise, 
the method from_url_encoded_string( SOURCE, * ) is used.

=cut

######################################################################
# This is the hook, called as _set...source( SOURCE[, *] )

sub _set_hash_with_nonhash_source {
	my ($self, $initializer, @rest) = @_;
	if( ref($initializer) eq 'GLOB' ) {
		$self->from_file( $initializer, @rest );
	} else {
		$self->from_url_encoded_string( $initializer, @rest );
	}
}

######################################################################

=head2 to_url_encoded_string([ DELIM[, VALSEP] ])

This method returns a scalar containing all of this object's keys and values
encoded in an url-escaped "query string" format.  The escaping format specifies
that any characters which aren't in [a-zA-Z0-9_ .-] are replaced with a triplet
containing a "%" followed by the two-hex-digit representation of the ascii value
for the character.  Also, any " " (space) is replaced with a "+".  Each key and
value pair is delimited by a "=".  If a key has multiple values, then there are
that many "key=value" pairs.  The optional argument, DELIM, is a scalar
specifying what to use as a delimiter between pairs.  This is "&" by default.  If
a "\n" is given for DELIM, the resulting string would be suitable for writing to
a file where each key=value pair is on a separate line.  The second optional
argument, VALSEP, is a scalar that specifies the delimiter between multiple
consecutive values which share a common key, and that key only appears once.  For
example, SOURCE could be "key1=val1&val2; key2=val3&val4", as is the case with
"cookie" strings (DELIM is "; " and VALSEP is "&") or "isindex" queries.

=cut

######################################################################

sub to_url_encoded_string {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my $delim_kvpair = shift( @_ ) || '&';
	my $delim_values = shift( @_ );
	my @result;

	foreach my $key (sort keys %{$rh_main_hash}) {
		my $key_enc = $key;
		$key_enc =~ s/([^\w .-])/'%'.sprintf("%2.2X",ord($1))/ge;
		$key_enc =~ tr/ /+/;

		my @values;

		foreach my $value (@{$rh_main_hash->{$key}}) {
			my $value_enc = $value;   # s/// on $value changes original
			$value_enc =~ s/([^\w .-])/'%'.sprintf("%2.2X",ord($1))/ge;
			$value_enc =~ tr/ /+/;

			push( @values, $value_enc );
		}

		push( @result, "$key_enc=".( 
			$delim_values ? join( $delim_values, @values ) :
			join( "$delim_kvpair$key_enc=", @values ) 
		) );
	}

	return( join( $delim_kvpair, @result ) );
}

######################################################################

=head2 from_url_encoded_string( SOURCE[, DELIM[, VALSEP]] )

This method takes a scalar, SOURCE, containing a set of keys and values encoded
in an url-escaped "query string" format, and adds them to this object.  The
escaping format specifies that any characters which aren't in [a-zA-Z0-9_ .-] are
replaced with a triplet containing a "%" followed by the two-hex-digit
representation of the ascii value for the character.  Also, any " " (space) is
replaced with a "+".  Each key and value pair is delimited by a "=".  If a key
has multiple values, then there are that many "key=value" pairs.  The first
optional argument, DELIM, is a scalar specifying what to use as a delimiter
between pairs. This is "&" by default.  If a "\n" is given for DELIM, the source
string was likely read from a file where each key=value pair is on a separate
line.  The second optional argument, VALSEP, is a scalar that specifies the
delimiter between multiple consecutive values which share a common key, and that
key only appears once.  For example, SOURCE could be "key1=val1&val2;
key2=val3&val4", as is the case with "cookie" strings (DELIM is "; " and VALSEP
is "&") or "isindex" queries.

=cut

######################################################################

sub from_url_encoded_string {
	my $self = shift( @_ );
	my $source_str = shift( @_ );
	my $delim_kvpair = shift( @_ ) || '&';
	my $delim_values = shift( @_ );
	my @source = split( $delim_kvpair, $source_str );

	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my $case_inse = $self->{$KEY_CASE_INSE};

	foreach my $pair (@source) {
		my ($key, $values_str) = split( '=', $pair, 2 );
		next if( $key eq "" );

		$key =~ tr/+/ /;
		$key =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
		$key = lc($key) if( $case_inse );
		$rh_main_hash->{$key} ||= [];

		my @values = $delim_values ? 
			split( $delim_values, $values_str ) : $values_str;

		foreach my $value (@values) {
			$value =~ tr/+/ /;
			$value =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
		
			push( @{$rh_main_hash->{$key}}, $value );
		}
	}

	return( scalar( @source ) );
}

######################################################################

=head2 to_file( FH[, DELIM[, VALSEP[, REC_DELIM[, EMPTY]]]]] )

This method encodes all of this object's keys and values using the
to_url_encoded_string( DELIM, VALSEP ) method and writes it to the filehandle
provided in FH.  The optional argument REC_DELIM is a scalar value that will be
written to FH before this encoded object, and serves to delimit multiple encoded
objects of this class.  The default values for [DELIM, VALSEP, REC_DELIM] are
["\n", undef, "\n=\n"].  If the boolean argument EMPTY is true then this object
will be written to FH even if it is empty (has no keys), resulting in only a
REC_DELIM actually being written.  The default behaviour of false prevents this
from happening, so only objects containing data are output.  This method returns
1 on a successful write, 0 for an empty record that was skipped, and it returns
undef on a file-system error.

=cut

######################################################################

sub to_file {
	my ($self, $fh, $delim_kvpair, $delim_values, $delim_recs, $use_empty) = @_;

	ref( $fh ) eq 'GLOB' or return( undef );

	$delim_kvpair ||= "\n";
	$delim_values ||= undef;
	$delim_recs ||= "\n=\n";
	
	local $\ = undef;

	!$self->keys_count() and !$use_empty and return( 0 );

	my $record_str = 
		$self->to_url_encoded_string( $delim_kvpair, $delim_values );

	print $fh "$delim_recs$record_str" or return( undef );
	
	return( 1 );
}

######################################################################

=head2 from_file( FH[, DELIM[, VALSEP[, REC_DELIM[, EMPTY]]]]] )

This method adds keys and values to this object from an encoded record read from 
the filehandle provided in FH and parsed with from_url_encoded_string( ., DELIM,
VALSEP ).  The optional argument REC_DELIM is a scalar value that delimits
encoded records in the file stream. The default values for [DELIM, VALSEP,
REC_DELIM] are ["\n", undef, "\n=\n"].  If the boolean argument EMPTY is true
then this object will be initialized to empty (has no keys) if the record
delimiter is encountered in the file stream before any valid encoded record.  The
default behaviour of false prevents this from happening, so the file stream
continues to be read until a valid record is found.  This method returns 1 on a
successful read, 0 for an empty record that was kept (may be end-of-file), and it
returns undef on a file-system error.

=cut

######################################################################

sub from_file {
	my ($self, $fh, $delim_kvpair, $delim_values, $delim_recs, $use_empty) = @_;

	ref( $fh ) eq 'GLOB' or return( undef );

	$delim_kvpair ||= "\n";
	$delim_values ||= undef;
	$delim_recs ||= "\n=\n";

	local $/ = $delim_recs;

	GET_ANOTHER_REC: {
		eof( $fh ) and return( 0 );

		defined( my $record_str = <$fh> ) or return( undef );
	
		$self->from_url_encoded_string( 
			$record_str, $delim_kvpair, $delim_values );
	
		$self->keys_count() and return( 1 );
	
		$use_empty and return( 0 );
	
		redo GET_ANOTHER_REC;
	}
}

######################################################################

=head2 to_html_encoded_table([ LINEBREAK ])

This method returns a scalar containing table html with all of this object's keys 
and values.  The table has two columns, with keys on the left and values on the 
right, and each row is one key and its values.  By default, the values appear 
comma-delimited, but if the optional boolean argument LINEBREAK is true, then 
the value list is delimited with <BR> tags instead, putting each value on its own 
line.  All keys and values are html-escaped such that any occurances of [&,",<,>] 
are substitued with [&amp;,&quot;,&gt;,&lt;].

=cut

######################################################################

sub to_html_encoded_hidden_fields {
	my ($self, $linebreak) = @_;
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my @result;

	push( @result, "<TABLE>\n" );

	foreach my $key (sort keys %{$rh_main_hash}) {
		push( @result, "<TR><TD>\n" );

		my $key_enc = $key;
		$key_enc =~ s/&/&amp;/g;
		$key_enc =~ s/\"/&quot;/g;
		$key_enc =~ s/>/&gt;/g;
		$key_enc =~ s/</&lt;/g;

		push( @result, "</TD><TD>\n" );

		my @enc_value_list;

		foreach my $value (@{$rh_main_hash->{$key}}) {
			my $value_enc = $value;   # s/// on $value changes original
			$value_enc =~ s/&/&amp;/g;
			$value_enc =~ s/\"/&quot;/g;
			$value_enc =~ s/>/&gt;/g;
			$value_enc =~ s/</&lt;/g;

			push( @enc_value_list, $value_enc );
		}
		
		push( @result, $linebreak ? join( "<BR>\n", @enc_value_list ) : 
			join( ", \n", @enc_value_list ) );
			
		push( @result, "</TD></TR>\n" );
	}

	push( @result, "<TABLE>\n" );

	return( join( '', @result ) );
}

######################################################################

=head2 to_html_encoded_hidden_fields()

This method returns a scalar containing html text which defines a list of hidden
form fields whose names and values are all of this object's keys and values. 
Each list element looks like '<INPUT TYPE="hidden" NAME="key" VALUE="value">'. 
Where a key has multiple values, a hidden field is made for each value.  All keys
and values are html-escaped such that any occurances of [&,",<,>] are substitued
with [&amp;,&quot;,&gt;,&lt;].  In cases where this object was storing user input
that was submitted using 'post', this method can generate the content of a
self-referencing form, should the main program need to call itself.  It would
handle persistant data which is too big to put in a self-referencing query
string.

=cut

######################################################################

sub to_html_encoded_hidden_fields {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my @result;

	foreach my $key (sort keys %{$rh_main_hash}) {
		my $key_enc = $key;
		$key_enc =~ s/&/&amp;/g;
		$key_enc =~ s/\"/&quot;/g;
		$key_enc =~ s/>/&gt;/g;
		$key_enc =~ s/</&lt;/g;

		foreach my $value (@{$rh_main_hash->{$key}}) {
			my $value_enc = $value;   # s/// on $value changes original
			$value_enc =~ s/&/&amp;/g;
			$value_enc =~ s/\"/&quot;/g;
			$value_enc =~ s/>/&gt;/g;
			$value_enc =~ s/</&lt;/g;

			push( @result, <<__endquote );
<INPUT TYPE="hidden" NAME="$key_enc" VALUE="$value_enc">
__endquote
		}
	}

	return( join( '', @result ) );
}

######################################################################

=head2 trim_bounding_whitespace()

This method cleans up all of this object's values by trimming any leading or
trailing whitespace.  The keys are left alone.  This would normally be done when
the object is representing user input from a form, including when they entered
nothing but whitespace, and the program should act like they left the field
empty.

=cut

######################################################################

sub trim_bounding_whitespace {
	my $self = shift( @_ );
	foreach my $ra_values (values %{$self->{$KEY_MAIN_HASH}}) {
		foreach my $value (@{$ra_values}) {
			$value =~ s/^\s+//;
			$value =~ s/\s+$//;
		}
	}
}

######################################################################

=head2 batch_to_file( FH, LIST[, DELIM[, VALSEP[, REC_DELIM[, EMPTY]]]]] )

This batch function writes encoded MVH objects to the filehandle provided in 
the first argument, FH.  The second argument, LIST, is an array ref containing 
the MVH objects or hash refs to be written.  Symantecs are similar to calling 
to_file( FH, * ) once on each MVH object; any remaining arguments are passed 
on as is to to_file().  If any array elements aren't
MVHs or HASH refs, they are disregarded.  This method returns
1 on success, even if there are no objects to write.  It returns undef on a
file-system error, even if some of the objects were written first.

=cut

######################################################################

sub batch_to_file {
	my $class = shift( @_ );
	my $fh = shift( @_ );
	my @mvh_list = ref($_[0]) eq 'ARRAY' ? @{shift(@_)} : shift(@_);

	ref( $fh ) eq 'GLOB' or return( undef );
	
	foreach my $mvh (@mvh_list) {
		ref( $mvh ) eq 'Data::MultiValuedHash' and 
			bless( $mvh, 'CGI::MultiValuedHash' );
		ref( $mvh ) eq 'HASH' and $mvh = 
			CGI::MultiValuedHash->new( 0, $mvh );
		ref( $mvh ) eq "CGI::MultiValuedHash" or next;
		
		defined( $mvh->to_file( $fh, @_ ) ) or return( undef );
	}
	
	return( 1 );
}

######################################################################

=head2 batch_from_file( FH, CASE[, MAX[, DELIM[, VALSEP[, REC_DELIM[, EMPTY]]]]] )

This batch function reads encoded MVH objects from the filehandle provided in 
the first argument, FH, and returns them in a list.  The second argument, CASE, 
specifies whether the new MVH objects are case-insensitive or not.  The third 
optional argument, MAX, specifies the maximum number of objects to read.
  If that argument is undefined or less than 1, then all objects are read
until the end-of-file is reached.  Symantecs are similar to calling 
from_file( FH, * ) once on each MVH object; any remaining arguments are passed 
on as is to from_file().  This method returns an ARRAY ref containing the new 
records (as MVHs)
on success, even if the end-of-file is reached before we find any records.  It
returns undef on a file-system error, even if some records were read first.

=cut

######################################################################

sub batch_from_file {
	my $class = shift( @_ );
	my $fh = shift( @_ );
	my $case_inse = shift( @_ );
	my $max_obj_num = shift( @_ );  # if <= 0, read all records
	my $use_empty = $_[3];  # fourth remaining argument

	ref( $fh ) eq 'GLOB' or return( undef );
	
	my @mvh_list = ();
	my $remaining_obj_count = ($max_obj_num <= 0) ? -1 : $max_obj_num;

	GET_ANOTHER_REC: {
		eof( $fh ) and last;

		my $mvh = CGI::MultiValuedHash->new( $case_inse );

		defined( $mvh->from_file( $fh, @_ ) ) or return( undef );

		push( @mvh_list, $mvh );

		--$remaining_obj_count != 0 and redo GET_ANOTHER_REC;
	}	
	
	# if file is of nonzero length and contains no records, or if it has a 
	# record separator followed by no records, then we would end up with an 
	# empty last record in our list even if empty records aren't allowed, 
	# so we get rid of said disallowed here
	if( !$use_empty and @mvh_list and !$mvh_list[-1]->keys_count() ) {
		pop( @mvh_list );
	}
	
	return( \@mvh_list );
}

######################################################################

1;
__END__

=head1 AUTHOR

Copyright (c) 1999-2001, Darren R. Duncan. All rights reserved. This module is
free software; you can redistribute it and/or modify it under the same terms as
Perl itself.  However, I do request that this copyright information remain
attached to the file.  If you modify this module and redistribute a changed
version then please attach a note listing the modifications.

I am always interested in knowing how my work helps others, so if you put this
module to use in any of your own code then please send me the URL. Also, if you
make modifications to the module because it doesn't work the way you need, please
send me a copy so that I can roll desirable changes into the main release.

Address comments, suggestions, and bug reports to B<perl@DarrenDuncan.net>.

=head1 CREDITS

Thanks to Johan Vromans <jvromans@squirrel.nl> for suggesting the split of my old
module "CGI::HashOfArrays" into the two current ones, "Data::MultiValuedHash" and
"CGI::MultiValuedHash".  This took care of a longstanding logistical problem
concerning whether the module was a generic data structure or a tool for
encoding/decoding CGI data.

Thanks to Steve Benson <steve.benson@stanford.edu> for suggesting POD
improvements in regards to the case-insensitivity feature, so the documentation
is easier to understand.

=head1 SEE ALSO

perl(1), Data::MultiValuedHash.

=cut
