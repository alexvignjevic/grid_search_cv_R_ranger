
# import libraries
library(ranger)
library(data.table)
library(mlr3verse)
library(janitor)


# import dataset
df<-data.table(read.csv("adult_income_dataset.csv"))

# clean names
df<-clean_names(df)

# convert independent variable to factor
df<-df[,income_50k:=as.factor(income_50k)]

# Specify task
task <- TaskClassif$new('df', df, target = 'income_50k', positive = '1')


# Use paramter space from mlr3verse to create search grid
sg = ps(max.depth  = p_int(lower = 2, upper = 4,trafo=function(x) 2*x+1),
        mtry  = p_int(lower = 1, upper = 3,trafo=function(x) 3*x),
        num.trees  = p_int(lower = 1, upper = 2,trafo=function(x) 50*x),
        min.node.size=p_int(lower=1,upper=3,trafo=function(x) {if (x ==3) {x+97} else if (x == 2) {x+48}  
          else {x+9}}),
        class.weights=p_int(lower = 1, upper = 2,trafo = function(x) 
        {if (x ==1) {c(1,1)} else {c(1,2)}}))

# create an instance
instance = ti(
  # pass task specified earlier
  task = task,
  # specify learner
  learner = lrn('classif.ranger',importance='impurity',seed=123),
  # specify resampling to be 'cv' for cross-validation and pick a number for k, 3 in this case
  resampling = rsmp('cv', folds = 3),
  # pass search_grid specified earlier
  search_space = sg,
  # choose a measure
  measures=msr('classif.ce'),
  # specify terminator
  terminator=trm('none')
)

# run the grid tuning
tnr('grid_search')$optimize(instance)

# get optimal parameters
instance$result$learner_param_vals

# look at classification error (or some other measure) passed to msr()
instance$result


# Run the model with optimal parameters
model<-ranger(income_50k~.,
              data=df,
              importance="impurity",
              max.depth=9,
              num.trees=50,
              mtry=9,
              min.node.size=100,
              class.weights=c(1,1),
              seed=123)

# create prediction object

pred_object <- predict(model, df, predict.all=TRUE)

# convert predictions to a data frame.  
# Each row will be a vector of predicted classes, 
# and each column is the index of the tree "voting" for that class

pred_object <- as.data.frame(pred_object$predictions)

# specify number of trees whcih are equal to the number of columns of pred_object dataframe

ntrees<-ncol(pred_object)

# Assign the proportion of trees that vote for "1" for each row to a df column

df$prob <- (rowSums( pred == 2 ) / ntrees)
