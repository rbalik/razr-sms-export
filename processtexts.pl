#!/usr/bin/perl

#Run script in msging. Looks into i for inbox and
#e for sent.
#The message bodies are in the _* subdirs
#We'll look at the message bodies first because them being
#there means the message wasn't deleted.
#Two characters before _smsbody match to the envelope files
#in the top directory
#Phone numbers in envelope. In "e" starts with 0x20C0
#In "i" starts with 0x11C0
#Timestamps on smsbody files are received/sent time of message

use strict;
use warnings;

use File::stat;
use Time::localtime;

my %numseps = ('i', "\x11\xC0", 'e', "\x20\xC0" );

#Fill in hash to match numbers to contacts
my %contacts = (
		'5551234567', 'TEST',
		);

my %msgdata;

foreach my $dir (keys(%numseps))
{
	my $msgtype = "in";
	if($dir eq 'e')
	{
		$msgtype = "out";
	}
	opendir(my $dh, $dir) or
		die("unable to open dir $dir");
	my @msgdirs = grep{ /^\_\d+/ && -d "$dir/$_" } readdir($dh);
	closedir($dh);

	foreach my $msgdir (@msgdirs)
	{
		opendir(my $mdh, "$dir/$msgdir");
		my @msgbodies = grep{ /_smsbody.data/ && -f
			"$dir/$msgdir/$_"} readdir($mdh);
		closedir($mdh);

		foreach my $msgbody (@msgbodies)
		{
			$msgbody =~ /(..)_smsbody/;
			my $msgcode = $1;
			open(my $smsbody, "<",
				"$dir/$msgdir/$msgbody") or
				die("can't open $msgbody\n");
			my $msgtext = "";
			my $msgtime = stat($smsbody)->mtime;
			while(<$smsbody>)
			{
				$msgtext .= $_;
			}
			close($smsbody);
			$msgtext =~ s/\x00//g;

			my $iscbfile = 0;
			my $filename = "$dir/$msgcode.env";
			if(!-f $filename)
			{
				$filename =
				    sprintf("$dir/$msgdir/%s_smscb.data",
						    $msgcode);
				if(-f $filename)
				{
					$iscbfile = 1;
				}
				else
				{
					next;
				}
			}

			open(my $smsenv, "<", $filename) or
				die("unable to open $filename\n");
			binmode($smsenv);
			my $rdbuf = '';
		        my $buf = '';
			my $len = 0;
			while(($len = read($smsenv, $rdbuf, 1024)) > 0)
			{
				$buf .= $rdbuf;
			}
			close($smsenv);

			my $phonenum = '';
			if($iscbfile == 0)
			{
				if($buf =~ m/$numseps{$dir}([\d\-\x00]+)/)
				{
					$phonenum = $1;
				}
			}
			else
			{
				$phonenum = $buf;
			}

			$phonenum =~ s/[\x00\-]//g;
			$phonenum =~ s/^1//;

			if(!exists($msgdata{$msgtime}))
			{
				$msgdata{$msgtime} = [];
			}
			my $dataref = {
					'text' => $msgtext,
					'number' => $phonenum,
					'type' => $msgtype,
					'code' => $msgcode
			};
			push(@{$msgdata{$msgtime}}, $dataref);
		}
	}
}

my %unknownnums;

foreach my $msgtime (sort(keys(%msgdata)))
{
	foreach my $msghash (@{$msgdata{$msgtime}})
	{
		my $prefix = '>';
		my $numprefix = "To You From";
		if(${$msghash}{'type'} eq 'out')
		{
			$prefix = '<';
			$numprefix = "From You To";
		}
		$prefix x= 40;
		my $name = '';
		if(exists($contacts{${$msghash}{'number'}}))
		{
			$name = $contacts{${$msghash}{'number'}};
		}
		else
		{
			if(!exists($unknownnums{$msghash->{'number'}}))
			{
				$unknownnums{$msghash->{'number'}} = 0;
			}
			$unknownnums{$msghash->{'number'}}++;
		}
		print("$prefix\n");
		printf("$numprefix: %s(%s)\n",
				${$msghash}{'number'},
				$name);
		printf("Date: %s\n", ctime($msgtime));
		printf("Text: %s\n", ${$msghash}{'text'});
		print("$prefix\n\n");
#printf("Code: %s\n\n", ${$msghash}{'code'});
	}
}

print("\n\n-----\nUnknown Numbers\n");

foreach my $num (sort(keys(%unknownnums)))
{
	print("$num\n");
}

exit(0);


