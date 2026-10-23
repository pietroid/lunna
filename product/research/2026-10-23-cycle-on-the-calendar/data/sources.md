# What the sources say, as fetched on 2026-10-23

## Flo, "To enable data sync in iOS" (help.flo.health/hc/en-us/articles/34890229122068, updated 2025-02-20)

> [Data points with access permission] will not be transferred from Flo to
> the Health app. For example, logged Menstruation data in Flo will not be
> sent to the Health app.

(Quoted through a fetch summary; the page refused a verbatim copy.)

Re-read on 2026-10-23 after review. The page's title is "How to import data
from the Health app to Flo (iOS)": the direction is Health → Flo. It also says
"Turning on the sync between these two apps will import any information you
previously logged into Flo."

## Apple Community, "Health app hasn't synced data from flo since November 2023" (discussions.apple.com/thread/255504055)

Original post, 2024-02-29: "the health app just stopped allowing data to be
written by the flo app." Flo support, quoted in a reply on 2024-03-04: "We
regret to inform you that the feature to sync your Flo data with Apple Health
is no longer available in the app." A forum post: secondary, but it matches
Flo's own help page.

## Flo, "How do I import info into Flo" (help.flo.health/hc/en-us/articles/360054973911)

> If your previous period tracking app syncs with the Health app, you can
> import the data from there.

Android: past periods are entered by hand ("Calendar > Edit period dates").

## Apple, Cycle Tracking Instructions for Use 4.0 (en_GB)

- Analyses "typical cycle length, typical period length, menstrual flow and
  ovulation test results, along with aggregates of sedentary heart rate and
  wrist temperature."
- "Period predictions can begin after you have entered at least two periods."
- Tested on 1,238 cycles from 260 users: "Period start predictions are within
  the limits of the equivalence bounds of +/– 3 days from the actual period
  start." EU: "includes the period start in displayed predictions 80% of the time."
- "User input data can be entered manually or imported from third-party apps."

## Apple, HKHealthStore.authorizationStatus(for:)

> To help prevent possible leaks of sensitive health information, your app
> cannot determine whether or not a user has granted permission to read
> data. If you are not given permission, it simply appears as if there is
> no data of the requested type in the HealthKit store.

## Apple, HKMetadataKeyMenstrualCycleStart

> A key that indicates whether the sample represents the start of a
> menstrual cycle. This metadata key is required for menstrualFlow category
> samples.

## Apple, App Store Review Guideline 5.1.3 (ii)

> Apps must not write false or inaccurate data into HealthKit or any other
> medical research or health management apps, and may not store personal
> health information in iCloud.

## Bull et al. 2019, npj Digital Medicine (PMC6710244, full text via Europe PMC)

612,613 ovulatory cycles, 124,648 users (Natural Cycles): mean cycle 29.3
days; follicular 16.9 (95% CI 10–30); luteal 12.4 (95% CI 7–17); 13% of
cycles were 28 days long.

## Li, Gibson & Jukic 2023, npj Digital Medicine (PMC10226714): Apple Women's Health Study

165,668 cycles, 12,608 participants: mean 28.7 days (SD 6.1), median 28
(IQR 26–30), 5–95th percentile 22–38. "The average within-individual
variability varied between 4–6 days across most of the age, ethnicity, and
BMI groups."

## McNulty et al. 2020, Sports Medicine 50(10):1813–1827

Exercise performance "might be trivially reduced during the early
follicular phase"; evidence quality rated low; no general guidelines,
a personalised approach instead.

## health 13.3.2 (pub.dev), lib/src/heath_data_types.dart

`MENSTRUATION_FLOW` is in both the iOS and the Android (Health Connect)
lists; its value carries `flow` and `isStartOfCycle`.
