graph TD
    subgraph "AWS Cloud"
        subgraph "VPC (10.1.0.0/16)"
            direction LR
            Internet(Internet) --> InternetGateway[Internet Gateway]
            InternetGateway --> RouterGW[Router]
            
            subgraph "Public Subnets"
                direction TB
                RouterGW --> ALB[Application Load Balancer]
                RouterGW --> ManagementEC2[Management Host]
            end

            subgraph "Private Subnets"
                direction TB
                RouterGW --> ASG[Auto Scaling Group]
            end

            ManagementEC2 -- SSH (22) --> ASG
            ALB -- HTTP (80) --> ASG
        end
    end
