function [stats, feature_scores]= ...
    nFold_AnyClassifier_withFeatureselection_v4(data_set,data_labels,feature_list,para,shuffle,n,nIter,Subsets)
% Input:
%   data_set: data
%   data_labels: labels
%   feature_list: the feature name list in cell
%   para:
%    parameter like what classifier you use, the number of top feature
%    para.classifier='LDA';
%    para.num_top_feature=5;
%    para.featureranking='wilcoxon';
%    para.correlation_factor=.9;
%   shuffle: 1 for random, 0 for non-random partition (Default: 1)
%   n: Number of folds to your cross-validation (Default: 3)
%   nIter: Number of cross-validation iterations (Default: 1)
%   Subsets: pass your own training and testing subsets & labels (Default:
%   computer will generate using 'nFold')
%
% Output:
%   stats: struct containing TP, FP, TN, FN, etc.
%   The function is written by Cheng Lu @2016
%   example here:
%   para.feature_score_method='weighted';
%   para.classifier='QDA';
%   para.num_top_feature=5;
%    para.featureranking='wilcoxon';
%    para.correlation_factor=.9;
%   intFolds=5;
%   intIter=50;
%   [resultImbalancedC45,feature_scores] = nFold_AnyClassifier_withFeatureselection_v3(data_all_w,labels,feature_list_t,para,1,intFolds,intIter);

% (c) Edited by Cheng Lu, 
% Biomedical Engineering,
% Case Western Reserve Univeristy, cleveland, OH. Aug, 2016
% If you have any problem feel free to contact me.
% Please address questions or comments to: hacylu@yahoo.com

% Terms of use: You are free to copy,
% distribute, display, and use this work, under the following
% conditions. (1) You must give the original authors credit. (2) You may
% not use or redistribute this work for commercial purposes. (3) You may
% not alter, transform, or build upon this work. (4) For any reuse or
% distribution, you must make clear to others the license terms of this
% work. (5) Any of these conditions can be waived if you get permission
% from the authors.
%

% v4 can return the balance acc 

data_labels=double(data_labels);

if nargin < 8
    Subsets = {};
end
if nargin < 7
    nIter = 1;
end
if nargin < 6
    n = 4; % 3-fold cross-validation
end
if nargin < 5
    shuffle = 1; % randomized
end

% if any(~xor(data_labels == 1, data_labels == -1)), error('Labels must be 1 and -1'); end
feature_scores=zeros(size(data_set,2),1);

if size(data_set,1)~=length(data_labels)
    error('the size of the feature data should be the same as the label data!!!');
end

stats = struct; %cell(1,nIter);
for j=1:nIter
    fprintf('Iteration: %i\n',j);
    
    % reset total statistics
    Ttp = 0; Ttn = 0; Tfp = 0; Tfn = 0;
    
    if isempty(Subsets)
        [tra, tes] = GenerateSubsets('nFold',data_set,data_labels,shuffle,n);
        decision=zeros(size(data_labels)); prediction=zeros(size(data_labels));
    else
        tra{1} = Subsets{j}.training;
        tes{1} = Subsets{j}.testing;
%         decision=zeros(size(tes{1})); prediction=zeros(size(tes{1}));
    end
    
    for i=1:n
        fprintf(['Fold # ' num2str(i) '\n']); 
        fprintf(1,'classifier: %s, feature_selection: %s\n', para.classifier,para.featureranking);
        training_set = data_set(tra{i},:);
        testing_set = data_set(tes{i},:);
        training_labels = data_labels(tra{i});
        testing_labels = data_labels(tes{i});
        
        %%% do feature selection on the fly
        %% first step FS-mrmr
%         dataw_discrete=makeDataDiscrete_mrmr(training_set);
% %             dataw_discrete=training_set>t; check check check
%         setAll=1:size(training_set,2);
%         [idx_TTest] = mrmr_mid_d(dataw_discrete(:,setAll), training_labels, 100);
%         training_set = training_set(:,idx_TTest);
%         testing_set = testing_set(:,idx_TTest);
        %% First step FS-lasso
%         idx_TTest = [];
%         [B, FitInfo] = lasso(training_set, training_labels, 'CV', 10);
%         for ii=1:size(B, 1)
%            if any(B(ii, :))
%               idx_TTest(end+1) = ii; 
%            end
%         end
%         training_set = training_set(:,idx_TTest);
%         testing_set = testing_set(:,idx_TTest);
        %% using mrmr
        if strcmp(para.featureranking,'mrmr')
            %         map the data in to binary values 0 1
            dataw_discrete=makeDataDiscrete_mrmr(training_set);
%             dataw_discrete=training_set>t; check check check
            setAll=1:size(training_set,2);
            [idx_TTest] = mrmr_mid_d(dataw_discrete(:,setAll), training_labels, para.num_top_feature);
        end
        if strcmp(para.featureranking,'FSmethod')
            [idx, ~] = rankfeatures(training_set',training_labels','criterion',para.FSmethod,'CCWeighting', 1,'NumberOfIndices',para.num_top_feature);
            idx_TTest=idx(1:para.num_top_feature); 
        end
        
        %% using random forest
        if strcmp(para.featureranking,'rf')
            options = statset('UseParallel','never','UseSubstreams','never');
            B = TreeBagger(50,training_set,training_labels,'FBoot',0.667, 'oobpred','on','OOBVarImp', 'on', 'Method','classification','NVarToSample','all','NPrint',4,'Options',options);
            variableimportance = B.OOBPermutedVarDeltaError;
            [t,idx]=sort(variableimportance,'descend');
            idx_TTest=idx(1:para.num_top_feature);
        end
        
        if strcmp(para.featureranking,'ttest') || strcmp(para.featureranking,'wilcoxon')
            if strcmp(para.featureranking,'ttest')
                [TTidx,confidence] = prunefeatures_new(training_set, training_labels, 'ttestp');
                idx_TTest=TTidx(confidence<0.05);
                if isempty(idx_TTest)
                    idx_TTest=TTidx(1:min(para.num_top_feature*2,size(data_set,2)));
                end
            end
            if strcmp(para.featureranking,'wilcoxon')
                [TTidx,confidence] = prunefeatures_new(training_set, training_labels, 'wilcoxon');
                idx_TTest=TTidx(confidence<0.05);
                if isempty(idx_TTest)
                    idx_TTest=TTidx(1:min(para.num_top_feature*3,size(data_set,2)));
                end
            end        
            %%% lock down top features with low correlation
            set_candiF=Lpick_top_n_features_with_pvalue_correlation(training_set,idx_TTest,para.num_top_feature,para.correlation_factor);
            idx_TTest=set_candiF;
        end
        %% added by Zengrui
        if strcmp(para.featureranking,'mutinffs');idx_TTest = mutInfFS( training_set, training_labels, para.num_top_feature );end
        if strcmp(para.featureranking,'fsv');idx_TTest = fsvFS( training_set, training_labels, para.num_top_feature );end
        if strcmp(para.featureranking,'mcfs') 
            options = [];
            options.k = 5; %For unsupervised feature selection, you should tune
            %this parameter k, the default k is 5.
            options.nUseEigenfunction = 4;  %You should tune this parameter.
            [FeaIndex,~] = MCFS_p(training_set,para.num_top_feature,options);
            idx_TTest = FeaIndex{1};
        end
        if strcmp(para.featureranking,'rfe');idx_TTest = spider_wrapper(training_set,training_labels,para.num_top_feature,para.featureranking);end
        if strcmp(para.featureranking,'l0');idx_TTest = spider_wrapper(training_set,training_labels,para.num_top_feature,para.featureranking);end
        if strcmp(para.featureranking,'fisher');idx_TTest = spider_wrapper(training_set,training_labels,para.num_top_feature,para.featureranking);end
        if strcmp(para.featureranking,'ilfs');idx_TTest = ILFS(training_set, training_labels , 4, 0 );end
        if strcmp(para.featureranking,'relieff');idx_TTest = reliefF( training_set, training_labels, 20);end
        if strcmp(para.featureranking,'laplacian') 
            W = dist(training_set');
            W = -W./max(max(W)); % it's a similarity
            [lscores] = LaplacianScore(training_set, W);
            [~, idx_TTest] = sort(-lscores);
        end   
        if strcmp(para.featureranking,'inffs') 
            alpha = 0.5;    % default, it should be cross-validated.
            sup = 1;        % Supervised or Not
            idx_TTest = infFS( training_set , training_labels, alpha , sup , 0 );
        end
        if strcmp(para.featureranking,'ecfs') 
            alpha = 0.5; % default, it should be cross-validated.
            idx_TTest = ECFS( training_set, training_labels, alpha );
        end
        if strcmp(para.featureranking,'udfs') 
            nClass = 2;
            idx_TTest = UDFS(training_set , nClass );
        end
        if strcmp(para.featureranking,'cfs');idx_TTest = cfs(training_set);end
        if strcmp(para.featureranking,'llcfs');idx_TTest = llcfs( training_set );end
        idx_TTest=idx_TTest(1:min(para.num_top_feature,length(idx_TTest)));
        %% feature score
        if  strcmp(para.feature_score_method,'addone')
            % add one value on the piceked features
            feature_scores(idx_TTest)=feature_scores(idx_TTest)+1;
        else  strcmp(para.feature_score_method,'weighted')
            feature_scores(idx_TTest)=feature_scores(idx_TTest)+ linspace( para.num_top_feature ,1, length(idx_TTest))';
        end
        fprintf('on the fold, %d features are picked ', length(idx_TTest));
        for iii = 1:length(idx_TTest);fprintf(',%d',idx_TTest(iii));end
        fprintf('\n');
        %% test on the testing set
        if strcmp(para.classifier,'QDA')|| strcmp(para.classifier,'qda')
            [temp_stats,methodstring] = Classify( 'QDA', training_set(:,idx_TTest) , testing_set(:,idx_TTest), training_labels(:), testing_labels(:));
        end

        if strcmp(para.classifier,'LDA') ||strcmp(para.classifier,'lda')
            [temp_stats,methodstring] = Classify( 'LDA', training_set(:,idx_TTest) , testing_set(:,idx_TTest), training_labels(:), testing_labels(:));
        end
        if strcmp(para.classifier,'SVM')||strcmp(para.classifier,'svm')
            if isfield(para, 'params')%
                params.kernel=para.params.kernel;
%                     params.c_range=para.params.c_range;
%                     params.g_range=para.params.g_range;
%                     params.cvfolds=para.params.cvfolds;
                [temp_stats,methodstring] = Classify( 'svmmine', training_set(:,idx_TTest) , testing_set(:,idx_TTest), training_labels(:), testing_labels(:));

            else
                [temp_stats,methodstring] = Classify( 'svmmine', training_set(:,idx_TTest) , testing_set(:,idx_TTest), training_labels(:), testing_labels(:));
            end
        end
        if strcmp(para.classifier,'NBayes')
            distrib = para.distrib;
            prior = para.prior;
            [temp_stats,methodstring] = Classify( 'NBayes', training_set(:,idx_TTest) , testing_set(:,idx_TTest), training_labels(:), testing_labels(:),distrib,prior);
        end
        if strcmp(para.classifier,'knn')
            [temp_stats,methodstring] = Classify( 'kNN', training_set(:,idx_TTest) , testing_set(:,idx_TTest), training_labels(:), testing_labels(:));
        end
        if strcmp(para.classifier,'tree')
            [temp_stats,methodstring] = Classify( 'tree', training_set(:,idx_TTest) , testing_set(:,idx_TTest), training_labels(:), testing_labels(:));
        end
        if strcmp(para.classifier,'ecoc')
            [temp_stats,methodstring] = Classify( 'ecoc', training_set(:,idx_TTest) , testing_set(:,idx_TTest), training_labels(:), testing_labels(:));
        end
        if strcmp(para.classifier,'glm')
            [temp_stats,methodstring] = Classify( 'glm', training_set(:,idx_TTest) , testing_set(:,idx_TTest), training_labels(:), testing_labels(:));
        end
        if strcmp(para.classifier,'ensemble')
            [temp_stats,methodstring] = Classify( 'ensemble', training_set(:,idx_TTest) , testing_set(:,idx_TTest), training_labels(:), testing_labels(:));
        end
        Ttp = Ttp + temp_stats.tp;
        Ttn = Ttn + temp_stats.tn;
        Tfp = Tfp + temp_stats.fp;
        Tfn = Tfn + temp_stats.fn;
        if ~isempty(Subsets)
            stats=temp_stats;
            return; 
        end
        prediction(tes{i}) = temp_stats.prediction;
    end    
    %% output statistics
    if numel(unique(data_labels))>1 %numel(unique(testing_labels))>1
        if n == 1
            [FPR,TPR,T,AUC,OPTROCPT,~,~] = perfcurve(data_labels(tes{i}),prediction(tes{i}),1);
        else
            [FPR,TPR,T,AUC,OPTROCPT,~,~] = perfcurve(data_labels,prediction,1);
        end
        stats(j).AUC = AUC;
        stats(j).TPR = TPR;
        stats(j).FPR = FPR;
    else
        stats(j).AUC = [];
        stats(j).TPR = [];
        stats(j).FPR = [];
    end
    
    stats(j).tp = Ttp;
    stats(j).tn = Ttn;
    stats(j).fp = Tfp;
    stats(j).fn = Tfn;
    stats(j).acc = (Ttp+Ttn)/(Ttp+Ttn+Tfp+Tfn);
    stats(j).ppv = Ttp/(Ttp+Tfp);
    stats(j).sens = Ttp/(Ttp+Tfn);
    stats(j).spec = Ttn/(Tfp+Ttn);
    stats(j).subsets.training = tra;
    stats(j).subsets.testing = tes;
    stats(j).labels = data_labels;
%     stats(j).decision = decision;
    stats(j).prediction = prediction;
    Pre = ((Ttp+Tfp)*(Ttp+Tfn) + (Ttn+Tfn)*(Ttn+Tfp)) / (Ttp+Ttn+Tfp+Tfn)^2;
    stats(j).kappa = (stats(j).acc - Pre) / (1 - Pre);
    
    % get a blance sens and spec to report
    if para.get_balance_sens_spec  
        spe=1-FPR;
        labels=stats(j).labels;
        balanceAcc=(spe+TPR)/2;
        [~,maxIdx]=max(balanceAcc);
        stats(j).sens=TPR(maxIdx);
        stats(j).spec=1-FPR(maxIdx);
        stats(j).tp=round(stats(j).sens*sum(labels));
        stats(j).tn=round(stats(j).spec*sum(~labels));
        stats(j).fp=sum(~labels)-stats(j).tn;
        stats(j).fn=sum(labels)-stats(j).tp;
        stats(j).acc=(stats(j).tp+stats(j).tn)/length(labels);
       %% modeified other metrics if neccesary !!
    end
end