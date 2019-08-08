
function rnascope_human(filename, toolbox)

% filename = '/dcl01/lieber/ajaffe/Maddy/RNAscope/human_pilot/3_28_19_Figure_4_Data_4plex_Human/Br1350/Br1350_Strip2_LayerVI_6_Linear unmixing.czi';
addpath(genpath(toolbox))

tic
warning('off','all');
out = ReadImage6D(filename);
warning('on','all');
X = out{2}.SizeX;
Y = out{2}.SizeY;
Z = out{2}.SizeZ;
%voxelSizeX = out{2}.ScaleX;
%voxelSizeY = out{2}.ScaleY;
%voxelSizeZ = out{2}.ScaleZ;
image6d = out{1}; %dims = series,time, z, c, x, y 

        O = out{2}.Dyes;
if isempty(find(cell2mat(O), 1))
        O = out{2}.Channels;
end

	
for i = 1:numel(O)-1
  v = char(O(i));
  v(~isstrprop(v,'alphanum')) = '_';
  v = ['img.',v];
  L = squeeze(image6d(:,:,:,i,:,:));
  S = size(L);
  
  if X==Y
      x = find(S==X);
      eval([v '= permute(L,[x(1),x(2),find(S==Z)]);']);
  elseif Z==1
      eval([v '= L']);
  else 
  	  eval([v '= permute(L,[find(S==Y),find(S==X),find(S==Z)]);']);
  end  
	  
end

clearex X Y Z filename out toolbox img 
	  
disp('extracted')
disp(fieldnames(img))
	toc 
	O = fieldnames(img);
for i = 1:numel(O)
	  %channe_i = ['im2double(img.',O{i},')']; %for rosehip
	  channe_i = ['rescale(img.',O{i},')'];
       
  if contains(channe_i, 'Lipofuscin')
      channel = eval(channe_i);
  	  Lip = i;
  elseif contains(channe_i,'DAPI')
	  channel = medfilt3(eval(channe_i),[19 19 3]);
	  DAPI = i;
  else
      channel = imhmin(eval(channe_i),std2(eval(channe_i)));% suppress background noise in RNA scope channels.
  end
  
   thresh = graythresh(channel); %for rosehip
   BWc = imbinarize(channel,thresh);
	  
	 %if thresh<0.04
	 %  BWc = imbinarize(channel,0.04);
	 %end
  
if contains(channe_i,'DAPI')
    BWc = imfill(BWc,'holes');
	bw3=max(BWc,[],3);
    D = -bwdist(~bw3);
    mask = imextendedmin(D,2);
    D2 = imimposemin(D,mask);
    Ld2 = watershed(D2);
    bw3(Ld2 == 0) = 0;
	
	for zi =1:Z	
		A = BWc(:,:,zi);
		A(bw3==0)=0;
		BWc(:,:,zi) = A;	 	
	end
	
else	 	 
	 x = imcomplement(channel);
	 x = imhmin(x,2*std(channel(:)));
	 L = watershed(x);
	 BWc(L==0) = 0;  
end	 

[segmented_dotsc,no_of_dots] = bwlabeln(BWc);
statsc = regionprops3(segmented_dotsc,eval(['img.',O{i}]),'Volume','Centroid','BoundingBox','MaxIntensity','MeanIntensity','MinIntensity','VoxelValues','VoxelList','VoxelIdxList');

disp(['segmented ',O{i}, ': ',num2str(no_of_dots)])


v = ['excel_totaldots.',O{i}];
	eval([v '= statsc;'])
v = ['Segmentations.',O{i}];
	eval([v '= BWc;']);
	
clearex X Y Z filename out toolbox img O Segmentations excel_totaldots i Lip DAPI
end

%%masking
	 
	 mask = O{Lip};		 
	 eval(['mask = Segmentations.',mask,';']);
	 Segmentations_m = Segmentations;
	 for i = 1:numel(O)
	 eval(['Segmentations_m.',O{i},'(mask) = 0;']);
	 channel = ['img.',O{i}]; Seg = ['Segmentations_m.',O{i}];
	 statsc = (regionprops3(eval(Seg),eval(channel),'Volume','Centroid','BoundingBox','MaxIntensity','MeanIntensity','MinIntensity','VoxelValues','VoxelList','VoxelIdxList'));
	 v = ['excel_totaldots_mask.',O{i}];
	 eval([v '= statsc;'])
	 disp(['Completed Masking ',O{i}]) 
	 end
		
	
		 
	cel = eval(['excel_totaldots.',O{DAPI},'.VoxelIdxList;']);
			 
	 for ii = setdiff(1:numel(O),[DAPI,Lip])
	    disp(['Started ',O{ii}])
		statsc = eval(['excel_totaldots.',O{ii},';']);
		statsc_m = eval(['excel_totaldots_mask.',O{ii},';']);
		
		 warning('off','all');
		 		tic
		 		dots_of_ROI = cell2table({{0},{0},0,{0},{0},{0}},'VariableNames',{'ROI','dotname','count','Volume','Location','Intensity'});
				dots_of_ROI_m = cell2table({{0},{0},0,{0},{0},{0}},'VariableNames',{'ROI','dotname','count','Volume','Location','Intensity'});
		 		for i = 1:numel(cel) % for loop to find dots in ROI%
		 			dots=cellfun(@(x) intersect(x,cel{i}), statsc.VoxelIdxList,'UniformOutput', false);
					dots_m=cellfun(@(x) intersect(x,cel{i}), statsc_m.VoxelIdxList,'UniformOutput', false);
		 			x = find(~cellfun(@isempty,dots));
					x_m = find(~cellfun(@isempty,dots_m));
		 			dots_of_ROI.ROI{i} = {sprintf('ROI%d',i)};
					dots_of_ROI_m.ROI{i} = {sprintf('ROI%d',i)};
		 			dots_of_ROI.dotname{i} = x;
					dots_of_ROI_m.dotname{i} = x_m;
		 			dots_of_ROI.count(i) = numel(x);
					dots_of_ROI_m.count(i) = numel(x_m);
		 			dots_of_ROI.Volume{i} = statsc.Volume(x);
					dots_of_ROI_m.Volume{i} = statsc_m.Volume(x_m);
		 			dots_of_ROI.Location{i} = statsc.VoxelIdxList(x);
					dots_of_ROI_m.Location{i} = statsc_m.VoxelIdxList(x_m);
		 			dots_of_ROI.Intensity{i} = statsc.VoxelValues(x);
					dots_of_ROI_m.Intensity{i} = statsc_m.VoxelValues(x_m);
		 		disp([num2str(i),' cells finished in time ', num2str(toc),'s'])
		 		clear x
				
		 		end
		 warning('on','all');
		 		v = ['excel_dots_of_ROI.',O{ii}];
		 		eval([v '= dots_of_ROI;'])
			 	v = ['excel_dots_of_ROI_mask.',O{ii}];
			 	eval([v '= dots_of_ROI_m;'])
	 end 	 
		 
save([filename(1:end-4),'_img.mat'],'img','-v7.3')
save([filename(1:end-4),'_segmentation.mat'],'Segmentations','Segmentations_m')
save([filename(1:end-4),'_totaldots.mat'],'excel_totaldots','excel_totaldots_mask') 
save([filename(1:end-4),'_dots_of_ROI.mat'],'excel_dots_of_ROI','excel_dots_of_ROI_mask') 
end