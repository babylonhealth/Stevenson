# CRP Implementation Details

One of the command handled by our Babylon Stevenson bot is `/crp`, which aims to create a CRP ticket on JIRA – especially, a specific type of ticket which takes part of our SSDLC (Secure Software Development LifeCycle) process in the company.

## Process description

This part of the SSDLC process consists of the following steps, that our Bots automates:

* Collecting the list of JIRA ticket references that will be included as part of the new release.
  * It does that by gathering the `git log` between the last tag of an app flavor and the newly-open release branch of that same app flavor, extracting the references of JIRA tickets from the commit messages
* Create a JIRA ticket on our dedicated "CRP" board in our JIRA instance
  * That ticket should contain the list of the JIRA tickets gathered from the previous step, in addition to some other fields
  * That ticket will later go through the validation process, having to reviewed before we could consider pushing the new version of the app to the Stores
* For each JIRA board which has at least one ticket listed in the CRP:
  * Create a JIRA Release in that board, for the new version about to be released
  * Set the "Fix Version" field of each ticket of this board appearing in the CRP to that new JIRA release

## Implementation details

// TODO
