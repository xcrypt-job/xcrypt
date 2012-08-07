package file_stager;

use strict;
use NEXT;
use builtin;
use File::Path;
use File::Copy;
use File::Spec;
use File::Basename;
use Cwd;
#use xcropt;
use jsconfig;

&add_key('JS_stage_in_files', 'JS_stage_out_files');

## ���������ե�����(���ơ����󥰥�����ץȡ�zip�ե�����)̾�Υꥹ��
our %all_make_file_list = ();

# ���󥹥ȥ饯��
sub new {
	my $class = shift;												# ���饹̾
	my $self = $class->NEXT::new(@_);								# ���֥������Ⱥ���
	my $staging_base_dir = "";										# ���ơ����󥰴��ǥ��쥯�ȥ�
	my %cfg = %{$jsconfig::jobsched_config{$self->{env}->{sched}}};	# �������塼�饪�֥�������

	# ���ơ����󥰥ե������ϥå���Υꥹ�Ȥ˳�Ǽ
	if(defined($self->{JS_stage_in_files})){
		$self->{stage_in_list} = analyze($self->{JS_stage_in_files}, 'in', @{$self->{VALUE}});
	}
	if(defined($self->{JS_stage_out_files})){
		$self->{stage_out_list} = analyze($self->{JS_stage_out_files}, 'out', @{$self->{VALUE}});
	}
	
	# ���ơ����󥰥١����ǥ��쥯�ȥ�γ�ǧ
	if(defined($self->{JS_staging_base_dir})){
		$staging_base_dir = $self->{JS_staging_base_dir};
	}elsif(defined($cfg{staging_base_dir})){
		$staging_base_dir = $cfg{staging_base_dir};
	}else{
		$staging_base_dir = '.';
	}
	$self->{staging_base_dir} = $staging_base_dir;

	# ���������֥ե�����̾
	$self->{stage_in_zip_file} = "stage_in_" . $self->{id} . ".zip";
	$self->{stage_out_zip_file} = "stage_out_" . $self->{id} . ".zip";

	# ����֥������塼��˥ե�����ž����ǽ�����뤫�γ�ǧ
	$self->{stage_in_files_set} = $cfg{stage_in_files};
	$self->{stage_out_files_set}= $cfg{stage_out_files};

	# Xcrypt�����ե����������
#	my @xcr_stage_in_files_list = ();	# ���ơ�������ե�����
	my @xcr_stage_in_files_list = ("$ENV{XCRYPT}/lib/data_extractor.pm", "$ENV{XCRYPT}/lib/data_generator.pm", "$ENV{XCRYPT}/lib/return_transmission.pm",);	# ���ơ�������ե�����
	$self->{xcr_stage_in_files_list} = \@xcr_stage_in_files_list;
	my @xcr_stage_out_files_list = ();	# ���ơ��������ȥե�����
	$self->{xcr_stage_out_files_list} = \@xcr_stage_out_files_list;

	# ���ơ����󥰥�����ץ�
	$self->{stage_in_job_file} = "stage_in_" . $self->{id} . ".sh";
	$self->{stage_out_job_file} = "stage_out_" . $self->{id} . ".sh";
	
	# �������λ�ե饰
	$self->{file_stager_initialized} = 1;

	return bless $self, $class;
}

#####################################################################################
##  �ե����륹�ơ�����������
##  stage_in_local:���ơ������󥢡������֥ե��������
#####################################################################################
sub before{
	my $self = shift;

	# stage_in_local�θƤӽФ�
	stage_in_local($self);

	# ����֥�����ץȤإ��ơ�������¹ԥ�����ץȤ��ɲ�
	if(defined($self->{stage_in_list})){
		$self->add_cmd_before_exe("if [ -f $self->{stage_in_job_file} ]; then");
		$self->add_cmd_before_exe("/bin/sh $self->{stage_in_job_file}");
		$self->add_cmd_before_exe("fi");
	}

	# ����֥�����ץȤإ��ơ��������ȼ¹ԥ�����ץȤ��ɲ�
	if(defined($self->{stage_out_list})){
		$self->add_cmd_after_exe("if [ -f $self->{stage_out_job_file} ]; then");
		$self->add_cmd_after_exe("/bin/sh $self->{stage_out_job_file}");
		$self->add_cmd_after_exe("fi");
	}
}

#################################################################################
##  �ե����륹�ơ����󥰤θ����
##  stage_out_local:���ơ��������ȥե����������
#################################################################################
sub after{
	my $self = shift;

	# stage_out_local�θƤӽФ�
	stage_out_local($self);
}

###############################################################################
#   �ե����륹�ơ����󥰤ˤ����ƤǤ������������֥ե������������
###############################################################################
sub finally{
	my $self = shift;

	# ���󥹥ȥ饯���μ¹Գ�ǧ
	unless(defined($self->{file_stager_initialized})) {
		unless(defined($self->{package_err_displayed}))
		{
			warn "There is a possibility that the order of the module is wrong\n";
			$self->{package_err_displayed} = 1;
		}
		return;
	}

	# ���ơ������󥢡������֥ե�����κ��
	my $stage_in_zip_file = File::Spec->catfile($self->{workdir}, $self->{stage_in_zip_file});
	if(-f $stage_in_zip_file){
		unlink($stage_in_zip_file);
		delete($all_make_file_list{$self->{stage_in_zip_file}});
	}

	# ���ơ��������ȥ��������֥ե�����κ��
	my $stage_out_zip_file = $self->{stage_out_zip_file};
	if(-f $stage_out_zip_file){
		unlink($stage_out_zip_file);
		delete($all_make_file_list{$self->{stage_out_zip_file}});
	}

	# ���ơ������󥹥���ץȤκ��
	my $stage_in_job_file = File::Spec->catfile($self->{workdir}, $self->{stage_in_job_file});
	if(-f $stage_in_job_file){
		unlink($stage_in_job_file);
		delete($all_make_file_list{$self->{stage_in_job_file}});
	}
	# ���ơ��������ȥ�����ץȤκ��
	my $stage_out_job_file = File::Spec->catfile($self->{workdir}, $self->{stage_out_job_file});
	if(-f $stage_out_job_file){
		unlink($stage_out_job_file);
		delete($all_make_file_list{$self->{stage_out_job_file}});
	}
}

#######################################################################################################
#  �����ʥ�ϥ�ɥ��
#  ����ե������������
#######################################################################################################
sub sigint_handler {
	foreach my $file(keys %all_make_file_list){
		if(-f $file){
			unlink($file);
		}
	}
}
sub sigterm_handler{
	foreach my $file(keys %all_make_file_list){
		if(-f $file){
			unlink($file);
		}
	}
}

########################################################################################################
##  ���ơ����󥰥ե�����('JS_stage_in_files'�ޤ���'JS_stage_out_files')��ϥå���Υꥹ�Ȥ˳�Ǽ�����֤�
##  ���ơ����󥰥ե�����ȥ��ơ����󥰤μ����RANGE���Ѳ��ͤ�������
########################################################################################################
sub analyze{
	my $stage_files = shift;	# ���ơ����󥰥ե�����
	my $stage_type = shift;		# ���ơ����󥰤μ���ʥ��ơ�������or���ơ��������ȡ�
	local @user::VALUE = @_;	# RANGE���ϰ�
	my $former = "";			# ž����
	my $ahead = "";				# ž����
	my @stage_hash_list = ();	# �ֵѤ���ϥå���ꥹ��

	# ���ơ������󡢥��ơ��������Ȥγ�ǧ
	if($stage_type eq 'in'){
		$former = "local_file";
		$ahead = "remote_file";
	}elsif($stage_type eq 'out'){
		$former = "remote_file";
		$ahead = "local_file";
	}

	# ���쥤
	if(ref($stage_files) eq 'ARRAY'){
		# ���֥롼����ȥ����顼�ǹ�������Ƥ��뤫��ǧ
		my $sub_or_scalar_flag = 1;
		for my $element(@{$stage_files}){
			if(ref($element) ne 'CODE' and ref(\$element) ne 'SCALAR'){
				$sub_or_scalar_flag = 0;
				last;
			}
		}
		# ���ƥ����顼�ȥ��֥롼����		
		if($sub_or_scalar_flag == 1){
			my $file_count = @{$stage_files};
			# 1�İʾ�
			if($file_count > 1){
				my $directory = "";
				if(ref(@{$stage_files}[$file_count-1]) eq 'CODE'){
					$directory = &{@{$stage_files}[$file_count-1]};
				}elsif(ref(\@{$stage_files}[$file_count-1]) eq 'SCALAR'){
					$directory = @{$stage_files}[$file_count-1];
				}
				for(my $i = 0; $i < $file_count-1; $i++){
					if(ref(@{$stage_files}[$i]) eq 'CODE'){	
						push(@stage_hash_list, {$former => &{@{$stage_files}[$i]}, $ahead => $directory});
					}elsif(ref(\@{$stage_files}[$i]) eq 'SCALAR'){
						push(@stage_hash_list, {$former => @{$stage_files}[$i], $ahead => $directory});
					}
				}
			}
			# 1��
			elsif($file_count == 1){
				if(ref(@{$stage_files}[0]) eq 'CODE'){
					push(@stage_hash_list, {$former => &{@{$stage_files}[0]}, $ahead => &{@{$stage_files}[0]}});
				}elsif(ref(\@{$stage_files}[0]) eq 'SCALAR'){
					if(@{$stage_files}[0] =~ /\*|\?/){
						my $directory = dirname(@{$stage_files}[0]);
						push(@stage_hash_list, {$former => @{$stage_files}[0], $ahead => $directory});
					}
					else{
						push(@stage_hash_list, {$former => @{$stage_files}[0], $ahead => @{$stage_files}[0]});
					}
				}
			}
			else{
				warn "It is a description outside specification\n";
				return;
			}
		}
		# ����ʳ�
		elsif($sub_or_scalar_flag == 0){
			foreach my $element(@{$stage_files}){
				# ���쥤
				if(ref($element) eq 'ARRAY'){
					my $file_count = @{$element};
					# 1�İʾ�
					if($file_count > 1){
						my $directory = "";		# ž����ǥ��쥯�ȥ�
						if(ref(@{$element}[$file_count-1]) eq 'CODE'){
							$directory = &{@{$element}[$file_count-1]};
						}elsif(ref(\@{$element}[$file_count-1]) eq 'SCALAR'){
							$directory = @{$element}[$file_count-1];
						}
						for(my $i = 0; $i < $file_count-1; $i++){
							if(ref(@{$element}[$i]) eq 'CODE'){
								push(@stage_hash_list, {$former => &{@{$element}[$i]}, $ahead => $directory});
							}elsif(ref(\@{$element}[$i]) eq 'SCALAR'){
								push(@stage_hash_list, {$former => @{$element}[$i], $ahead => $directory});
							}
						}
					}
					# 1��
					elsif($file_count == 1){
						if(ref(@{$element}[0]) eq 'CODE'){
							push(@stage_hash_list, {$former => &{@{$element}[0]}, $ahead => &{@{$element}[0]}});
						}elsif(ref(\@{$element}[0]) eq 'SCALAR'){
							if(@{$element}[0] = ~ /\*|\?/){
								my $directory = dirname(@{$element}[0]);
								push(@stage_hash_list, {$former => @{$element}[0], $ahead => $directory});
							}else{
								push(@stage_hash_list, {$former => @{$element}[0], $ahead => @{$element}[0]});
							}
						}
					}
					else{
						warn "It is a description outside specification \n";
						return;
					}
				}
				# �ϥå���
				elsif(ref($element) eq 'HASH'){
					if($element->{local_file} && $element->{remote_file}){
						if(ref($element->{local_file}) eq 'CODE' and ref($element->{remote_file}) eq 'CODE'){
							push(@stage_hash_list, {local_file => &{$element->{local_file}}, remote_file => &{$element->{remote_file}}});
						}elsif(ref($element->{local_file}) eq 'CODE'){
							push(@stage_hash_list, {local_file => &{$element->{local_file}}, remote_file => $element->{remote_file}});
						}elsif(ref($element->{remote_file}) eq 'CODE'){
							push(@stage_hash_list, {local_file => $element->{local_file}, remote_file => &{$element->{remote_file}}});
						}else{
							push(@stage_hash_list, {local_file => $element->{local_file}, remote_file => $element->{remote_file}});
						}
					}
				}
				# �����顼
				elsif(ref(\$element) eq 'SCALAR'){
					if($element =~ /\*|\?/){
						my $directory = dirname($element);
						push(@stage_hash_list, {$former => $element, $ahead => $directory});
					}else{
						push(@stage_hash_list, {$former => $element, $ahead => $element});
					}
				}
				# ���֥롼����
				elsif(ref($element) eq 'CODE'){
					push(@stage_hash_list, {$former => &{$element}, $ahead => &{$element}});
				}
				else{
					warn "It is a description outside specification \n";
					return;
				}
			}
		}
	}
	# ���֥롼����
	elsif(ref($stage_files) eq 'CODE'){
		my @file_list = &{$stage_files};
		my $file_count = @file_list;
		if($file_count > 1){
			for(my $i = 0; $i < $file_count -1; $i++){
				push(@stage_hash_list, {$former => $file_list[$i], $ahead => $file_list[$file_count - 1]});
			}
		}
		elsif($file_count == 1){
			push(@stage_hash_list, {$former => &{$stage_files}, $ahead => &{$stage_files}});
		}
	}
	# ������	
	elsif(ref(\$stage_files) eq 'SCALAR'){
		my @file_list =  split(/\s*,\s*/,  $stage_files);
		my $file_count = @file_list;
		if($file_count > 1){
			for(my $i = 0; $i < $file_count -1; $i++){
				push(@stage_hash_list, {$former => $file_list[$i], $ahead => $file_list[$file_count - 1]});
			}
		}
		elsif($file_count == 1){
			if($file_list[0] =~ /\*|\?/){
				my $directory = dirname($file_list[0]);
				push(@stage_hash_list, {$former => $file_list[0], $ahead => $directory});
			}else{
				push(@stage_hash_list, {$former => $file_list[0], $ahead => $file_list[0]});
			}
		}
	}
	else{
		warn "It is a description outside specification \n";
		return;
	}

	return \@stage_hash_list;
}

###############################################################################
#   ��� ���������¦�ˤ����륹�ơ���������� ��� 
#   ���ơ��������оݥե����뤫�饢�������֥ե�����������
#   ����֥������塼��˥��������֥ե�����̾���Ϥ�
###############################################################################
sub stage_in_local{	
    my $self = shift;

    # ���󥹥ȥ饯���μ¹Գ�ǧ
	unless(defined($self->{file_stager_initialized})) {
		unless(defined($self->{package_err_displayed}))
		{
			warn "There is a possibility that the order of the module is wrong\n";
			$self->{package_err_displayed} = 1;
		}
		return;
	}

	# �Х륯����Ѥ������
	# �ҥ���֤Υ��ơ����󥰥ե������ƥ���֤��ɲ�
	if($self->{bulked_jobs}){
		foreach my $bulk_hash(@{$self->{bulked_jobs}}){
			if(defined($bulk_hash->{stage_in_list})){
				push(@{$self->{stage_in_list}}, @{$bulk_hash->{stage_in_list}});
			}
			if(defined($bulk_hash->{stage_out_list})){
				push(@{$self->{stage_out_list}}, @{$bulk_hash->{stage_out_list}});
			}
		}
	}

	# ���ơ�������ν���
	if(defined($self->{stage_in_list})) {
		# ����֥��֥������Ȥ��饹�ơ��������оݥե���������������
		my $stage_in_hash_list = $self->{'stage_in_list'};

		# ���ơ��������оݥե�����('local_file'�Τ�)������������	
		my @stage_in_files = ();
		foreach my $ref_stage_in_hash(@{$stage_in_hash_list}) {
			my %stage_in_file = %{$ref_stage_in_hash};
			push(@stage_in_files, $stage_in_file{'local_file'});
		}
		
		# ���������֥ե�������֤��Ƥ�������ǥ��쥯�ȥ�κ���
		my $tmpdir = $$ . '_' . $self->{id};
		mkdir($tmpdir);
		unless(-d $tmpdir) {
			warn "Cannot create the tmpdir '$tmpdir' at $self->{id}_stage_in\n";
			return;
		}

		# ���ơ�������ե�����Υ���ܥ�å���󥯤����ǥ��쥯�ȥ�˺���
		my $jobdir = getcwd();
		my $index = 0;
		my $is_exists_stage_in_file = 0;	# ���ơ��������оݥե����뤬���ĤǤ⤢�����1
		foreach my $stage_in_file(@stage_in_files){
			my @tmp_filelist = glob($stage_in_file);
			my @file_list = ();
			# �ե������̵ͭ�γ�ǧ
			foreach my $tmp_file(@tmp_filelist){
				if(-f $tmp_file){
					push(@file_list, $tmp_file);
				}else{
					warn "stage_in_file $tmp_file doesn't exist at $self->{id}_stage_in\n";
				}
			}
			# ����ܥ�å���󥯤κ���
			my $tmp_index_dir = File::Spec->catfile( $tmpdir, $index );
			mkdir($tmp_index_dir);
			foreach my $stage_file(@file_list){
				my $former_file = File::Spec->rel2abs($stage_file);
				chdir($tmp_index_dir);
				symlink($former_file, basename($former_file));
				chdir($jobdir);
				$is_exists_stage_in_file = 1;
			}
			++ $index;
		}

		# ���ơ��������оݥե����뤬���ĤǤ⤢����
		my $stage_in_zip_file = File::Spec->catfile($self->{workdir}, $self->{stage_in_zip_file});
		my $stage_in_job_file = File::Spec->catfile($self->{workdir}, $self->{stage_in_job_file});
		if($is_exists_stage_in_file) {
			# �����ʥ�ϥ�ɥ�󥰽����Ѥ˥ե�����̾�򵭲�
			$all_make_file_list{$stage_in_zip_file} = '';
		    
		    # ����ܥ�å���󥯤���zip�ե���������
		    chdir($tmpdir);
		    my $args = join(' ', (0..$index-1));
		    system("/usr/bin/zip $self->{stage_in_zip_file} -r $args >/dev/null 2>&1");
			chdir($jobdir);
			move("$tmpdir/$self->{stage_in_zip_file}", "$self->{workdir}");

			# ���ơ�������zip�ե����뤬������
			if(-f $stage_in_zip_file){
				# stage_in_job.sh�κ���
				if(defined($self->{stage_in_list})){
					my $ret = open (STAGE_IN, "> $stage_in_job_file");
					if($ret) {
						my $stage_in_script = stage_in_job($self);
						print STAGE_IN "$stage_in_script";
						close(STAGE_IN);
						$all_make_file_list{$self->{stage_in_job_file}} = '';
					}
					else{
						warn "Cannot open $self->{stage_in_job_file} at $self->{id}_stage_in\n";
					}
				}
			}
			else{
				warn "Cannot create the '$stage_in_zip_file' at $self->{id}_stage_in\n";
			}
		}
		else {
			warn "Any staging object file doesn't exist at $self->{id}_stage_in\n";
		}
		rmtree($tmpdir); 
	}
	
	# ���ơ��������Ȥν���
	if(defined($self->{stage_out_list})) {
		# stage_out_job.sh�κ���
			my $stage_out_job_file = File::Spec->catfile($self->{workdir}, $self->{stage_out_job_file});
			my $ret = open (STAGE_OUT, "> $stage_out_job_file");
			if($ret) {
				my $sage_out_script = stage_out_job($self);
				print STAGE_OUT "$sage_out_script";
				close(STAGE_OUT);
				$all_make_file_list{$self->{stage_out_job_file}} = '';
			}
			else{
				warn "Cannot open $self->{stage_out_job_file} at $self->{id}_stage_out\n";
			}
	}
	
	# ����֥������塼��˥��ơ�������IF������������硢ž���ե�����ꥹ�Ȥ��Ϥ�
	if(defined($self->{"stage_in_files_set"})) {
		my $stage_in_zip_file = File::Spec->catfile($self->{workdir}, $self->{stage_in_zip_file});
		if(-f $stage_in_zip_file) {
			push(@{$self->{xcr_stage_in_files_list}}, $self->{stage_in_zip_file});
		}
		my $stage_in_job_file = File::Spec->catfile($self->{workdir}, $self->{stage_in_job_file});
		if(-f $stage_in_job_file){
			push(@{$self->{xcr_stage_in_files_list}}, $self->{stage_in_job_file});
		}
		my $stage_out_job_file = File::Spec->catfile($self->{workdir}, $self->{stage_out_job_file});
		if (-f $stage_out_job_file){
			push(@{$self->{xcr_stage_in_files_list}}, $self->{stage_out_job_file});
		}
		if(defined($self->{before_in_job_file})){
			push(@{$self->{xcr_stage_in_files_list}}, $self->{before_in_job_file});
		}
		if(defined($self->{after_in_job_file})){
			push(@{$self->{xcr_stage_in_files_list}}, $self->{after_in_job_file});
		}
		if(defined($self->{exe_in_job_file})){
			push(@{$self->{xcr_stage_in_files_list}}, $self->{exe_in_job_file});
		}
		if(@{$self->{xcr_stage_in_files_list}} > 0){
			$self->{"stage_in_files_set"}(@{$self->{xcr_stage_in_files_list}});
		}
	}
	
	# ����֥������塼��˥��ơ���������IF������������硢ž���ե�����ꥹ�Ȥ��Ϥ�
	if(defined($self->{"stage_out_files_set"})) {
		if(defined($self->{stage_out_list})) {
			$all_make_file_list{$self->{stage_out_zip_file}} = '';
			push(@{$self->{xcr_stage_out_files_list}}, $self->{"stage_out_zip_file"});
		}	
		my $running_file = $self->{id} . "_is_running";
		push(@{$self->{xcr_stage_out_files_list}}, $running_file);
		my $done_file = $self->{id} . "_is_done";
		push(@{$self->{xcr_stage_out_files_list}}, $done_file);
		if(@{$self->{xcr_stage_out_files_list}} > 0){
			$self->{"stage_out_files_set"}(@{$self->{xcr_stage_out_files_list}});
		}
	}
}

###############################################################################
#   ��� ����ּ¹Է׻���¦�ˤ����륹�ơ���������� ��� 
#   ���ơ������󥢡������֥ե������Ÿ������ʸ������֤���
#   ��ʸ����ϡ�stage_in_job ������ץȤˤʤ롣
###############################################################################
sub stage_in_job{
	my $self = shift;
	my $cmd = "";		#�ֵѤ���ʸ����

	# ����֥��֥������Ȥ��饹�ơ��������оݥե���������������
	my $stage_in_hash_list = $self->{'stage_in_list'};
	
	# ���ơ����󥰥ե������'remote_file'������������
	my @stage_in_files = ();
	foreach my $stage_in_ref_hash(@{$stage_in_hash_list}){
		my %stage_in_hash = %{$stage_in_ref_hash};
		push(@stage_in_files, $stage_in_hash{remote_file});  
	}
	
	# �оݥե����뤬̵�����϶�ʸ������֤�
	if(@stage_in_files <= 0) {
		return $cmd;
	}

	# ���ơ������󥢡������֥ե������Ÿ������ʸ����κ���
	my $stage_in_files_list_text = join(' ', map {"'" . $_ . "'";} @stage_in_files);
$cmd .= <<__STAGE_IN_SCRIPT__;
#!/bin/sh
jobdir=`pwd`
if [ -f "$self->{stage_in_zip_file}" ];then
	:
else
	printf "'$self->{stage_in_zip_file}' not found\\n" 1>&2
	exit 99
fi
cd "$self->{staging_base_dir}"
if [ \$\? -ne 0 ]; then
	printf "failed to chdir '$self->{staging_base_dir}'\\n" 1>&2
	exit 99
fi
if [ -f "$self->{stage_in_zip_file}" ];then
	:
else
	cd "\$jobdir"
	if [ \$\? -ne 0 ]; then
		printf "failed to chdir '\$jobdir'\\n" 1>&2
		exit 99
	fi
	mv "$self->{stage_in_zip_file}" "$self->{staging_base_dir}"
	if [ \$\? -ne 0 ]; then
		printf "failed to move. from '$self->{stage_in_zip_file}' to '$self->{staging_base_dir}'.\\n" 1>&2
		exit 99
	fi
	cd "$self->{staging_base_dir}"
fi
tmpdir=\$\$_$self->{id}
mkdir "\$tmpdir"
if [ \$\? -ne 0 ]; then
	printf "Failed to create the directory '\$tmpdir'\\n" 1>&2
	exit 99
fi
mv "$self->{stage_in_zip_file}" "\$tmpdir"
cd "\$tmpdir"
/usr/bin/unzip "$self->{stage_in_zip_file}" >/dev/null 2>&1
if [ -d "0/" ]; then
	:
else
	printf "Cannot Decompression '$self->{stage_in_zip_file} at $self->{id}_stage_in'\\n" 1>&2
	cd "\$jobdir"
	/bin/rm -rf "\$tmpdir"
	exit 99
fi
cd "\$jobdir"
index=0
for stage_in_file in $stage_in_files_list_text
do
	cd "$self->{staging_base_dir}"
	if [ "\$stage_in_file" ]; then
		:
	else
		printf "The forwarding site is empty at $self->{id}_stage_in\\n" 1>&2
	fi
	tmp_index_dir=`pwd`/"\$tmpdir"/\$index
	ahead=`pwd`/"\$stage_in_file"
	cd "\$tmp_index_dir"
	if [ \$\? -eq 0 ]; then
		for stage_file in ./*
		do
			if [ -f "\$stage_file" ]; then
				mv "\${stage_file}" "\${ahead}"
				if [ \$\? -ne 0 ]; then
					printf "Failed to stage in '\$stage_file'\\n" 1>&2
				fi
			fi
		done
	fi
	cd "\$jobdir"
	index=`expr \$index + 1`
done
cd "$self->{staging_base_dir}"
/bin/rm -rf "\$tmpdir"
cd "\$jobdir"
exit 0
__STAGE_IN_SCRIPT__
	return $cmd;
}

###############################################################################
#   ��� ����ּ¹Է׻���¦�ˤ����륹�ơ��������Ƚ��� ��� 
#   ���ơ����������оݥե�����ꥹ�Ȥ򥢡������֤���ʸ������֤���
#   ��ʸ����ϡ�stage_out_job������ץȤˤʤ�
###############################################################################
sub stage_out_job{
    my $self = shift;
    my $cmd = "";		# �ֵѤ���ʸ����
	
	# ����֥��֥������Ȥ��饹�ơ����������оݥե���������������
	my $stage_out_hash_list = $self->{'stage_out_list'};
	
	# ���ơ����������оݥե�����('remote_file'�Τ�)������������
	my @stage_out_files = ();
	foreach my $ref_stage_out_hash(@{$stage_out_hash_list}) {
		my %stage_out_file = %{$ref_stage_out_hash};
		push(@stage_out_files, $stage_out_file{'remote_file'});
	}

	# �оݥե����뤬̵�����϶�ʸ������֤�
	if(@stage_out_files <= 0) {
		return $cmd;
	}

	# ���ơ��������ȥե�����򥢡������֤��륹����ץ�ʸ����κ���
	my $stage_out_files_list_text = join(' ', map {"'" . $_ . "'";} @stage_out_files);
$cmd .= <<__STAGE_OUT_SCRIPT__;
#!/bin/sh
jobdir=`pwd`
cd "$self->{staging_base_dir}"
if [ \$\? -ne 0 ]; then
	printf "Failed to chdir '$self->{staging_base_dir}'\\n" 1>&2
	exit 99
fi
tmpdir=\$\$_$self->{id}
tmpdir=`pwd`/"\$tmpdir"
mkdir "\$tmpdir"
if [ \$\? -ne 0 ]; then
	printf "Failed to create the directory '\$tmpdir'\\n" 1>&2
	exit 99
fi
cd "\$jobdir"
index=0
exists_stage_out_file=0
for stage_out_file in $stage_out_files_list_text
do
	cd "$self->{staging_base_dir}"
	tmp_file_list=`/bin/ls \$stage_out_file`
	tmp_index_dir="\$tmpdir"/"\$index"
	mkdir "\$tmp_index_dir"
	for stage_file in \$tmp_file_list
	do
		if [ -f "\$stage_file" ]; then
			former_file=`pwd`/"\$stage_file"
			cd "\$tmp_index_dir"
			former_file_basename=`basename "\$former_file"`
			ln -s "\$former_file" "\$former_file_basename"
			exists_stage_out_file=1
		else
			printf "stage_out_file '\$stage_file' doesn't exist\\n" 1>&2
		fi
		cd "\$jobdir"
		cd "$self->{staging_base_dir}"
	done
	index=`expr \$index + 1`
done
if [ \$exists_stage_out_file -eq 1 ]; then
	cd "\$tmpdir"
	arg=""
	i=0
	while [ \$i -lt \$index ];
	do
		arg=\${arg}" \$i"
		i=`expr \$i + 1`
	done
	/usr/bin/zip "$self->{stage_out_zip_file}" -r \$arg >/dev/null 2>&1
	if [ -f "$self->{stage_out_zip_file}" ]; then
		cd "\$jobdir"
		mv "\$tmpdir/$self->{stage_out_zip_file}" .
		if [ \$\? -ne 0 ]; then
			printf "Failed to create the zip file '$self->{stage_out_zip_file}'\\n" 1>&2
		fi
		cd "$self->{staging_base_dir}"
	else
		printf "Cannot create '$self->{stage_out_zip_file}'\n" 1>&2
	fi
	cd \$jobdir
else
	printf "Any staging object file doesn't exist\\n" 1>&2
fi
/bin/rm -rf "\$tmpdir"
exit 0
__STAGE_OUT_SCRIPT__
	return $cmd;
}

###############################################################################
#   ��� ���������¦�ˤ����륹�ơ��������Ƚ��� ��� 
#   ���ơ��������ȥ��������֥ե������Ÿ�����롣
###############################################################################
sub stage_out_local{
	my $self = shift;
	unless(defined($self->{file_stager_initialized})) {
		unless(defined($self->{package_err_displayed}))
		{
			warn "There is a possibility that the order of the module is wrong\n";
			$self->{package_err_displayed} = 1;
		}
		return;
	}

	if(defined($self->{stage_out_list})) {
		my $jobdir = getcwd();

		# ����֥��֥������Ȥ��饹�ơ����������оݥե���������������
		my $stage_out_hash_list = $self->{'stage_out_list'};

		# ���ơ��������оݥե�����('local_file'�Τ�)������������	
		my @stage_out_files = ();
		foreach my $ref_stage_out_hash(@{$stage_out_hash_list}) {
			my %stage_out_file = %{$ref_stage_out_hash};
			push(@stage_out_files, $stage_out_file{'local_file'});
		}

		# ����֥ǥ��쥯�ȥ�إ��������֥ե�������ư		
		chdir("$self->{workdir}");
		if(-f "$self->{stage_out_zip_file}"){
			move("$self->{stage_out_zip_file}", "$jobdir");
		}
		chdir($jobdir);
		chdir($self->{staging_base_dir});
		if(-f $self->{stage_out_zip_file}){
			move("$self->{stage_out_zip_file}", "$jobdir");
		}
		chdir($jobdir);

		# ���������֥ե������¸��̵ͭ���ǧ
		unless(-f $self->{stage_out_zip_file}) {
			#warn "'$self->{stage_out_zip_file}' not found\n";
			return;
		}

		# ���������֥ե������Ÿ���������ǥ��쥯�ȥ�κ���
		my $tmpdir = $$ . '_' . $self->{id};
		mkdir($tmpdir, 0777);
		unless(-d $tmpdir) {
			warn "Cannot create the tmpdir '$tmpdir' at $self->{id}_stage_out\n";
			return;
		}
		# ���������֥ե���������ǥ��쥯�ȥ�˰�ư
		move("$self->{stage_out_zip_file}", "$tmpdir") or warn "Failed to move '$self->{stage_out_zip_file}': $! at $self->{id}_stage_out\n";
		
		# ���������֥ե������Ÿ��
		chdir($tmpdir);
		copy("$self->{stage_out_zip_file}", "$ENV{HOME}/cvs/xcrypt/xcrypt-hg/");
		system("/usr/bin/unzip $self->{stage_out_zip_file}>/dev/null 2>&1");
		unless(-d "0/"){
			warn "Cannot Decompression the zipfile '$self->{stage_out_zip_file} at $self->{id}_stage_out'\n";
		}
		chdir($jobdir);
		
		# �ƥե����������
		my $index = 0;
		foreach my $stage_out_file(@stage_out_files){
			if($stage_out_file eq ''){
				warn "The forwarding site is empty at $self->{id}_stage_out\n";
			}
			else{
				my $ahead = File::Spec->rel2abs($stage_out_file);
				if($stage_out_file =~ /\/$/){
					$ahead = $ahead . '/';
				}
				my $tmp_index_dir = File::Spec->catfile( $tmpdir, $index );
				my $result = chdir($tmp_index_dir);
				if($result == 1){
					my @filelist = glob("./*");
					if(@filelist == 0){
						warn "The zip file is empty at $self->{id}_stage_out\n";
					}
					foreach my $stage_file(@filelist){
						if(-f $stage_file){
							move($stage_file, $ahead) or warn "Failed to stage out '$stage_file': $! at $self->{id}_stage_out\n";
						}
					}
				}
			}
			++ $index;
			chdir($jobdir);
		}	
		# ����ǥ��쥯�ȥ����
		rmtree($tmpdir);
	}
}

1;
