# My GCP IAM Learning Journey: Step-by-Step Guide

## Introduction

I decided to dive deep into Google Cloud Platform (GCP) and learn about cloud security from the ground up. This walkthrough documents my experience setting up Identity and Access Management (IAM) policies. I quickly discovered that IAM policies are absolutely crucial for managing access to cloud resources - especially for data engineering workflows where security can make or break a project.

## What I Needed to Get Started

- Basic understanding of cloud computing
- A Google Cloud Platform (GCP) account (I used the free tier)
- Basic knowledge of command-line interface (CLI)

## My Setup and Tools

1. **GCP Account**: I signed up for the free GCP account to get started
2. **Google Cloud Console**: I spent most of my time learning the web interface first
3. **Google Cloud SDK**: I installed this on my local machine to learn the CLI approach

## My Step-by-Step Learning Process

### Step 1: Setting Up My First GCP Project

**1.1 Accessing the Google Cloud Console**
- I opened my web browser and navigated to [Google Cloud Console](https://console.cloud.google.com/)
- I signed in with my Google account

**1.2 Creating My New Project**
- I looked for the project drop-down menu at the top of the page
- I clicked on the project drop-down and selected "New Project"
- In the "Project name" field, I entered: `my-gcp-project`
- I clicked "Create" and waited for it to finish

**1.3 Verifying My Project Creation**
- I waited about 30-60 seconds for the project to be created
- I saw a notification confirming the project was created successfully
- The project selector showed my new `my-gcp-project`

**What I Achieved**: A new GCP project named `my-gcp-project` was ready for me to configure.

### Step 2: Enabling Billing and APIs

**2.1 Setting Up Billing**
- I navigated to the Google Cloud Console menu (☰) and clicked "Billing"
- I didn't have a billing account, so I clicked "Create Account"
- I followed the prompts to set up billing (had to add payment method)
- Once my billing account was ready, I linked it to my project:
  - I selected my project `my-gcp-project`
  - I clicked "Link Account"

**2.2 Enabling Required APIs**
- I went to the navigation menu → "APIs & Services" → "Library"
- I searched for "Compute Engine API"
- I clicked on "Compute Engine API" from the results
- I clicked "Enable" and waited a few seconds

**What I Achieved**: Billing was enabled for my project and Compute Engine API was activated.

### Step 3: Creating My First Service Account

**3.1 Navigating to Service Accounts**
- I went to the navigation menu → "IAM & Admin" → "Service Accounts"
- I made sure my project `my-gcp-project` was selected

**3.2 Creating My New Service Account**
- I clicked the "Create Service Account" button at the top
- I filled in the service account details:
  - **Service account name**: `my-service-account`
  - **Service account ID**: This auto-populated as `my-service-account@[project-id].iam.gserviceaccount.com`
  - **Description**: I added "Service account for IAM testing"

**3.3 Granting Permissions**
- I clicked "Create and Continue"
- In the "Grant this service account access to project" section:
  - I clicked "Select a role" → chose "Viewer" from the "Basic" category
- I clicked "Continue"
- I skipped the "Grant users access to this service account" step and clicked "Done"

**What I Achieved**: My service account `my-service-account` was created with Viewer role permissions.

### Step 4: Assigning IAM Roles to Users

**4.1 Navigating to IAM Management**
- I went to the navigation menu → "IAM & Admin" → "IAM"
- I made sure my project `my-gcp-project` was selected

**4.2 Adding a New User**
- I clicked the "Add" button at the top of the IAM page
- In the "New members" field, I entered my email address

**4.3 Assigning Roles**
- I clicked "Select a role"
- I chose "Editor" from the "Basic" category for full access
  - (Note: I learned to be careful with "Owner" role!)

**4.4 Saving Changes**
- I clicked "Save" to apply the permissions
- The changes took effect immediately

**What I Achieved**: I now had the Editor role in my GCP project.

### Step 5: Learning to Use gcloud CLI for IAM

**5.1 Installing and Setting Up gcloud CLI**
- I downloaded and installed Google Cloud SDK from: https://cloud.google.com/sdk/docs/install
- I opened my terminal/command prompt

**5.2 Authenticating with Google Cloud**
```bash
gcloud auth login
```
- This opened a browser window where I signed in with my Google account
- I granted permissions to gcloud CLI

**5.3 Setting My Active Project**
```bash
gcloud config set project my-gcp-project
```
- I verified the project was set correctly:
```bash
gcloud config list project
```

**5.4 Creating My Custom Role Definition**
- I created a new file named `role-definition.json`
- I added this content:
```json
{
  "title": "CustomRole",
  "description": "A custom role for specific tasks",
  "stage": "GA",
  "includedPermissions": [
    "compute.instances.list",
    "compute.instances.stop",
    "compute.instances.start"
  ]
}
```

**5.5 Creating the Custom Role**
```bash
gcloud iam roles create CustomRole --project my-gcp-project --file role-definition.json
```

**5.6 Assigning the Custom Role to My User**
- I replaced `example-user@gmail.com` with my actual email:
```bash
gcloud projects add-iam-policy-binding my-gcp-project --member="user:akshitamalayathi2006@gmail.com" --role="projects/my-gcp-project/roles/CustomRole"
```

**5.7 Verifying the Assignment**
```bash
gcloud projects get-iam-policy my-gcp-project
```

**What I Achieved**: I successfully created a custom IAM role and assigned it to myself using gcloud CLI!

## My Project Conclusion

By completing this hands-on project, I successfully:
- Set up a GCP project from scratch (learned this takes patience!)
- Enabled billing and necessary APIs (billing setup was trickier than expected)
- Created and configured service accounts
- Assigned IAM roles to users
- Created custom IAM roles using both Console and gcloud CLI

These skills are essential for managing access control in GCP effectively, and I now understand why they form the foundation for secure cloud resource management. This project really opened my eyes to how important security is in cloud computing!
