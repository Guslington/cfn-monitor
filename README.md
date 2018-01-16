# cloudwatch-monitoring
CloudWatch Monitoring

## Configuration
Create a symlink named "ciinaboxes" with a target of your base2-ciinabox repo (similar to ciinabox-jenkins)

Example (with cloudwatch-monitoring and base2-ciinabox in the same directory):
```bash
cd cloudwatch-monitoring
ln -s ../base2-ciinabox ciinaboxes
```

## Usage
```bash
rake cfn:generate [ciinabox-name]
```

## Alarm configuration
All configuration takes place in the base2-ciinabox repo under the customer's ciinabox directory.
Create a directory name "monitoring" (similar to the "jenkins" directory for ciinabox-jenkins), this directory will contain the "alarms.yml" file and optional "templates.yml" file.

### alarms.yml
This file is used to configure the AWS resources you want to monitor with CloudWatch. Resources are referenced by the CloudFormation logical resource ID used to create them. Nested stacks are also referenced by their CloudFormation logical resource ID.

```YAML
source_bucket: [Name of S3 bucket where CloudFormation templates will be deployed]

resources:
  [nested stack name].[resource name]: [template name]
```

Example:

```YAML
source_bucket: source.customer.com

resources:
  RDSStack.RDS: RDSInstance
```

#### Target group configuration:
Target group alarms in CloudWatch require dimensions for both the target group and its associated load balancer.
To configure a target group alarm provide the logical ID of the target group (including any stacks it's nested under) followed by "/", followed by the logical ID of the load balancer (also including any stacks it's nested under).

Example:
```YAML
resources:
  LoadBalancerStack.WebDefTargetGroup/LoadBalancerStack.WebLoadBalancer: ApplicationELBTargetGroup
```

#### Multiple templates
You can specify multiple templates for the resource by providing a list/array. You may want to do this if you want to deploy some custom alarms in addition to the default alarms for a resource.

Example:
```YAML
resources:
  RDSStack.RDS: [ 'RDSInstance', 'MyRDSInstance' ]
```
or
```YAML
resources:
  RDSStack.RDS:
    - RDSInstance
    - MyRDSInstance
```

#### Templates
The "template" value you specify for a resource refers to either a default template in the `config/templates.yml` file of this repo, or a custom/override template in the `monitoring/templates.yml` file of the customer's ciinabox monitoring directory. This template can contain multiple alarms. The example below shows the default `RDSInstance` template, which has 2 alarms (`FreeStorageSpaceCrit` and `FreeStorageSpaceTask`). Using the `RDSInstance` template in this example will create 2 CloudWatch alarms for the `RDS` resource in the `RDSStack` nested stack.

Example: `alarms.yml`
```YAML
resources:
  RDSStack.RDS: RDSInstance
```
Example: `templates.yml`
```YAML
templates:
  RDSInstance: # AWS::RDS::DBInstance
    FreeStorageSpaceCrit:
      AlarmActions: crit
      Namespace: AWS/RDS
      MetricName: FreeStorageSpace
      ComparisonOperator: LessThanThreshold
      DimensionsName: DBInstanceIdentifier
      Statistic: Minimum
      Threshold: 50000000000
      Threshold.development: 10000000000
      EvaluationPeriods: 1
    FreeStorageSpaceTask:
      AlarmActions: task
      Namespace: AWS/RDS
      MetricName: FreeStorageSpace
      ComparisonOperator: LessThanThreshold
      DimensionsName: DBInstanceIdentifier
      Statistic: Minimum
      Threshold: 100000000000
      Threshold.development: 20000000000
      EvaluationPeriods: 1
```

### templates.yml

You should start by using the default templates in `cloudwatch-monitoring/config/templates.yml` and override, replace or augment them with custom templates in `base2-ciinabox/[customer]/monitoring/templates` as required.

#### Globally overriding a template

You can override a default template in the customer's `templates.yml` file if all instances of a particular resource require a non standard configuration for that customer.

Example:
```YAML
templates:
  RDSInstance:
    FreeStorageSpaceCrit:
      Threshold: 80000000000
```

This configuration will be merged over the default `RDSInstance` template resulting in the following:

```YAML
templates:
  RDSInstance:
    FreeStorageSpaceCrit:
      AlarmActions: crit
      Namespace: AWS/RDS
      MetricName: FreeStorageSpace
      ComparisonOperator: LessThanThreshold
      DimensionsName: DBInstanceIdentifier
      Statistic: Minimum
      Threshold: 80000000000
      Threshold.development: 10000000000
      EvaluationPeriods: 1
    FreeStorageSpaceTask:
      AlarmActions: task
      Namespace: AWS/RDS
      MetricName: FreeStorageSpace
      ComparisonOperator: LessThanThreshold
      DimensionsName: DBInstanceIdentifier
      Statistic: Minimum
      Threshold: 100000000000
      Threshold.development: 20000000000
      EvaluationPeriods: 1
```

#### Create a custom template
If the default template for your resource is completely inappropriate, you can create your own custom template in the `monitoring/templates.yml` file.

Example:

```YAML
templates:
  MyRDSInstance:
    DatabaseConnections:
      AlarmActions: crit
      Namespace: AWS/RDS
      MetricName: DatabaseConnections
      ComparisonOperator: MoreThanThreshold
      DimensionsName: DBInstanceIdentifier
      Statistic: Average
      Threshold: 20
      EvaluationPeriods: 5
```

#### Inherit a template
If you have multiple instances of a particular resource and you want to adjust the configuration for only some of them, you can create your own custom template which inherits the configuration of a default template.

Example:
```YAML
templates:
  MyRDSInstance:
    template: RDSInstance
    FreeStorageSpaceCrit:
      Threshold: 80000000000
```
The above example creates a new template `MyRDSInstance` which can now be used by one or many resources. The `MyRDSInstance` template inherits all of the alarms and configuration from `RDSInstance`, but sets `Threshold` to `80000000000` for the `FreeStorageSpaceCrit` alarm.

#### Environment type mappings
You can create environment type mappings if alarm configurations need to differ between different environment types. This may be useful in situations where development type environments are running different resource quantities or sizes.

Example:
```YAML
templates:
  RDSInstance:
    FreeStorageSpaceCrit:
      Threshold: 40000000000
      Threshold.development: 20000000000
      Threshold.staging: 30000000000
      EvaluationPeriods: 5
```
The above example shows different `Threshold` values for `EnvironmentType` values of `production` (default), `development` or `staging`.
Any value can be specified using the `.envType` syntax and the necessary mappings and `EnvironmentType` will be generated when rendered.
The `EvaluationPeriods` value for `development` and `staging` type environments will be `5` in the above example as no `.envType` values where provided for this parameter.

Supported Parameters:
Parameter | Mapping support
--- | ---
ActionsEnabled | true
AlarmActions | false
AlarmDescription | false
ComparisonOperator | true
Dimensions | false
EvaluateLowSampleCountPercentile | false
EvaluationPeriods | true
ExtendedStatistic | false
InsufficientDataActions | false
MetricName | true
Namespace | true
OKActions | false
Period | true
Statistic | true
Threshold | true
TreatMissingData | true
Unit | false

#### Alarm Actions
There are 3 classes of alarm actions: `crit`, `warn` and `task`.

Action | Process
--- | ---
crit | Alert on-call technician
warn | Create alarm in pager service but do not alert on-call technician
task | Create support ticket for investigation

An SNS topic is required per alarm action, these topics and their subscriptions are managed outside this stack

### Deployment

The rendered CloudFormation templates should be deployed to `[source_bucket]/cloudformation/monitoring/`.
Launch the Monitoring stack in the desired account with the following CloudFormation parameters:

Parameter Key | Parameter Value
--- | ---
EnvironmentType | `production` / `development` / `custom env type`
MonitoredStack | The name of the stack you want monitored. EG `prod`
MonitoringDisabled | `true` for disables alerts, `false` for enabled alerts
SnsTopicCrit | SNS topic used by crit type alarms
SnsTopicTask | SNS topic used by task type alarms
SnsTopicWarn | SNS topic used by warn type alarms

### Disabling Monitoring
It is possible to globally disable / snooze / downtime all alarms by setting the `MonitoringDisabled` CloudFormation parameter to `true`.
This will disable alarm actions without removing removing them.
