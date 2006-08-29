package TOC::AIMUtils;

sub normalize
{
	my $sn = lc shift;
	$sn =~ s/\s+//g;
	return $sn;
}

1;
