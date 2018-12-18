function [tp,tn,fp,fn,prediction] = run_demo( data_set , data_labels, kernel, varargin)

%%sample data
% data_set = [ 1 2 3 4 5; 1 2 3 4 5; 1 2 3 4 5; 5 4 3 2 1; 5 4 3 2 1; 5 4 3 2 1];
% data_labels = [ -1 -1 -1 1 1 1]';

% Runs a demo on a given data set.
% This is an example on what should be done to train and predict on a data set. The information
% is not stored externally but it prints important information on screen. It gives a quick idea
% on how the SVM is doing.
% The data set is divided internally in the training set and testing set. Options are provided to
% select the training set randomly or just select a specific number of postive and negative examples
% for training.
%
% Parameters
%   data_set    list of eamples arranged by rows.
%       - N observations x P features
%   data_labels list of labels corresponding to the examples.
%       - labels [-1 -1 -1  1  1  1]'

train_name = 'demonstration';

if size(data_labels,1) == 1, data_labels = data_labels'; end
    
    
data_labels = ((data_labels - 1)*2)-1; %format ground truth labels
% 1. First, we acquire the training set, training labels, testing set and testing labels.
%    For this, we will divide our data set in two. We will find positive (a)
%    and negative (b) examples to create a balanced training set.

if nargin > 3
    n = varargin{1};
    i = varargin{2};
[training_set,training_labels,testing_set,testing_labels] = loo_cross_validation(data_set,data_labels,n,i);
else
    n = 3;
    i = 1;
[training_set,training_labels,testing_set,testing_labels] = training_config(data_set,data_labels,n,i);
end

% 2. Perform cross validation on the training set. This will return three of the best values
%    (not necessarily the best three) so we choose the first value only.

[ c , g ] = cv_svm( train_name ,  training_set , training_labels , kernel);
c = c(1);
g = g(1);

% 3. Train the SVM with these parameters and the training set we selected. The training name
%    will be the prefix to all of the generated files.
train_svm( train_name , training_set , training_labels , c , g ,kernel);

% 4. Run the prediction on the test set using the generated training file.
%    *It will return a vector with the distances from all the points to the
%    hyper-plane.
prediction = predict_svm(  train_name , testing_set );

% 5. This prediction allows us to draw an ROC curve.
%[ spec sens area ] = roc_svm( prediction , testing_labels );
%plot( 1-spec , sens);

% 6. And we can also calculate the accuracy.
[ tp , tn , fp , fn ] = count_values( prediction , testing_labels ) ;

%fprintf('Area:        %f\n' , area );
% fprintf(' %5.3f ' , (tp+tn)/(tp+tn+fp+fn) );
% fprintf(' %5.3f ', tp/(tp+fp));
% fprintf(' %5.3f ' , tp/(tp+fn) );
% fprintf(' %5.3f ' , tn/(tn+fp) );

acc = (tp+tn)/(tp+tn+fp+fn);  %compute accuracy
%ppv = tp/(tp+fp);
%sens = tp/(tp+fn);
%spec = tn/(fp+tn);


if ispc
!del demonstration*.*
!del decision_values.txt
else
    system('rm demonstration*.*');
    % system('rm decision_values.txt')
end


function [training_set,training_labels,testing_set,testing_labels] = training_config(data_set,data_labels, n, i)
% data_set: n x d matrix
% labels: 1 x n vector
% n: n-fold cross validation
% i: test on fold i

a = find( data_labels >  0 );
b = find( data_labels <= 0 );

% define n sets
% a_cuts = round((1:n-1)/n*size(a,1));
a_cuts = [0 round((1:n-1)/n*size(a,1)) size(a,1)];
b_cuts = [0 round((1:n-1)/n*size(b,1)) size(b,1)];

% for i=1:length(a_cuts)-1

% commit a random portion of the dataset for training
a_shuffle = randperm(size(a,1));    %randomize index
b_shuffle = randperm(size(b,1));    %randomize index

    % commit 1 set from each class for testing
    a_values = a_shuffle(a_cuts(i)+1:a_cuts(i+1));
    b_values = b_shuffle(b_cuts(i)+1:b_cuts(i+1));
  
    testing_set    = data_set( [ a(a_values) ; b(b_values) ] , : );
    testing_labels = data_labels( [ a(a_values) ; b(b_values) ] , : );  
    
    % select training by eliminating testing samples from pool
    training_set = data_set;
    training_labels = data_labels;
    
    training_set([ a(a_values) ; b(b_values) ] , : ) = [];
    training_labels([ a(a_values) ; b(b_values) ] , : ) = [];


function [training_data,training_labels,testing_data,testing_labels] = loo_cross_validation(data_set,data_labels,i)

    testing_data = data_set(i,:);
    testing_labels = data_labels(i);
    
    data_set(i,:) = [];
    data_labels(i) = [];
    training_data = data_set;
    training_labels = data_labels;
    