#!/usr/bin/env bash
BASE="https://tsm-shell.fly.dev/api/hc/nodes"

curl -s -X POST $BASE/operations -H "Content-Type: application/json" -d '{
  "system":"HonorHealth","location":"Scottsdale - Shea","officeName":"Scottsdale Shea Office",
  "officeManager":"Dee Montee","findings":"Intake queue at 31 with 18-case backlog. Staffing at 86% — 2 FTE gap on front desk. No-show rate 9.2% inflating reschedule burden. Morning slot utilization at 67% vs 89% target.",
  "queueDepth":31,"intakeBacklog":18,"staffingCoverage":86,"noShowRate":9.2,"slotUtilization":67
}' | head -c 50

curl -s -X POST $BASE/billing -H "Content-Type: application/json" -d '{
  "system":"HonorHealth","location":"Scottsdale - Shea","officeName":"Scottsdale Shea Office",
  "officeManager":"Dee Montee","findings":"Denial rate 12.4% vs 5% target — 148 claims affected. AR>30 at $185K, concentrated in Medicare CO-29 timely filing (45%) and Aetna CO-4 (28%). Claim lag 6 days vs 3-day benchmark. $78K recoverable within 72h if resubmitted today.",
  "denialRate":12.4,"claimLagDays":6,"arOver30":185000,"pendingClaimsValue":240000,"cleanClaimRate":87.6
}' | head -c 50

curl -s -X POST $BASE/insurance -H "Content-Type: application/json" -d '{
  "system":"HonorHealth","location":"Scottsdale - Shea","officeName":"Scottsdale Shea Office",
  "officeManager":"Dee Montee","findings":"Auth backlog 27 cases, avg delay 56h vs 24h target. 9 cases >72h requiring peer-to-peer review. Medicare prior auth friction on cardiac and imaging CPTs. $240K in pending claims tied to unresolved auths.",
  "authBacklog":27,"authDelayHours":56,"pendingClaimsValue":240000,"payerFocus":"Medicare Prior Auth"
}' | head -c 50

curl -s -X POST $BASE/medical -H "Content-Type: application/json" -d '{
  "system":"HonorHealth","location":"Scottsdale - Shea",
  "findings":"Chart completion rate 79% vs 95% target. 22-case documentation backlog flagged for physician review. 11 high-volume CPT codes (99215, 93454) with modifier-25 compliance risk. ICD-10 specificity gaps on 34 charts affecting clean claim rate.",
  "chartCompletionRate":79,"docBacklog":22,"highVolumeFlags":11
}' | head -c 50

curl -s -X POST $BASE/compliance -H "Content-Type: application/json" -d '{
  "system":"HonorHealth","location":"Scottsdale - Shea",
  "findings":"9 open audit items, 3 HIPAA flags requiring 30-day remediation. Documentation gap rate 18% — above 10% threshold. OIG watchlist review due in 14 days. Modifier-25 overuse on 47 claims ($8,460 audit risk).",
  "openAuditItems":9,"docGapRate":18,"hipaaFlags":3,"auditRiskValue":8460
}' | head -c 50

curl -s -X POST $BASE/financial -H "Content-Type: application/json" -d '{
  "system":"HonorHealth","location":"Scottsdale - Shea",
  "findings":"AR aging avg 38 days vs 30-day target. Revenue drag $47K tied to 19 delayed claims in adjudication. Cash acceleration opportunity $109K within 14 days if top denial lanes cleared. Net collection rate 91.2% vs 95% benchmark.",
  "arAgingDays":38,"revenueDrag":47000,"delayedClaimsCount":19,"netCollectionRate":91.2
}' | head -c 50

curl -s -X POST $BASE/pharmacy -H "Content-Type: application/json" -d '{
  "system":"HonorHealth","location":"Scottsdale - Shea",
  "findings":"7 controlled substance documentation exceptions pending DEA review. Fill rate 88% vs 95% target — 17 scripts on hold pending auth. Rx volume 142 today, 12% above capacity. Prior auth required on 23 high-cost biologics.",
  "rxVolume":142,"controlledExceptions":7,"fillRate":88,"authPendingRx":23
}' | head -c 50

curl -s -X POST $BASE/legal -H "Content-Type: application/json" -d '{
  "system":"HonorHealth","location":"Scottsdale - Shea",
  "findings":"5 vendor contracts up for renewal within 30 days — 2 flagged for renegotiation. 3 HIPAA BAA reviews pending. Payer contract with Aetna expiring in 45 days, reimbursement rate at risk. 1 active grievance requiring 30-day response.",
  "openContracts":5,"hipaaReviewPending":3,"renewalWindowDays":30
}' | head -c 50

curl -s -X POST $BASE/vendors -H "Content-Type: application/json" -d '{
  "system":"HonorHealth","location":"Scottsdale - Shea",
  "findings":"3 of 12 active vendors flagged as at-risk — EHR integration vendor SLA breach 2 consecutive weeks. Medical supply dependency score 72/100. Clearinghouse rejection rate up 4% this month. Backup vendor contract not in place for billing scrub tool.",
  "activeVendors":12,"atRiskVendors":3,"dependencyScore":72
}' | head -c 50

curl -s -X POST $BASE/grants -H "Content-Type: application/json" -d '{
  "system":"HonorHealth","location":"Scottsdale - Shea",
  "findings":"4 active grants with reporting windows open. HRSA reporting due in 14 days — 60% complete. CMS Innovation grant milestone submission pending. Compliance rate 91% but 2 grants require additional documentation before close.",
  "openGrants":4,"reportingWindowDays":14,"complianceRate":91
}' | head -c 50

curl -s -X POST $BASE/taxprep -H "Content-Type: application/json" -d '{
  "system":"HonorHealth","location":"Scottsdale - Shea",
  "findings":"6 filings pending with deadline 12 days out. Readiness score 84/100 — missing 2 depreciation schedules and 1 1099 reconciliation. $2.1M revenue figure requires audit trail documentation. Prior year amended return still open with IRS.",
  "filingsPending":6,"deadlineDaysOut":12,"readinessScore":84
}' | head -c 50

echo ""
echo "All nodes updated"
