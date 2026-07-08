// pulse-score-v0 Noir-style circuit spike.
//
// This proves a threshold over private coarse buckets. It does not prove
// HealthKit provenance, sensor origin, app integrity, or honest extraction of
// the private inputs.

fn main(
    challenge_hash: pub Field,
    policy_version: pub Field,
    expires_at_epoch_minutes: pub u32,
    min_expires_at_epoch_minutes: pub u32,
    max_expires_at_epoch_minutes: pub u32,
    threshold_score: pub u16,
    high_threshold_score: pub u16,
    claimed_score_tier: pub u8,
    feature_commitment: pub Field,
    recency_bucket: u8,
    continuity_bucket: u8,
    source_confidence_bucket: u8,
    signal_count_bucket: u8,
    user_entered_samples_excluded: bool,
) {
    assert(policy_version == 0);
    assert(expires_at_epoch_minutes >= min_expires_at_epoch_minutes);
    assert(expires_at_epoch_minutes <= max_expires_at_epoch_minutes);
    assert(high_threshold_score >= threshold_score);

    assert(recency_bucket <= 3);
    assert(continuity_bucket <= 3);
    assert(source_confidence_bucket <= 2);
    assert(signal_count_bucket <= 3);

    let score = score_features(
        recency_bucket,
        continuity_bucket,
        source_confidence_bucket,
        signal_count_bucket,
        user_entered_samples_excluded,
    );

    let actual_tier = score_tier(score, threshold_score, high_threshold_score);
    assert(actual_tier == claimed_score_tier);
    assert(claimed_score_tier > 0);

    let expected_commitment = toy_feature_commitment(
        challenge_hash,
        policy_version,
        recency_bucket,
        continuity_bucket,
        source_confidence_bucket,
        signal_count_bucket,
        user_entered_samples_excluded,
    );
    assert(expected_commitment == feature_commitment);
}

fn score_features(
    recency_bucket: u8,
    continuity_bucket: u8,
    source_confidence_bucket: u8,
    signal_count_bucket: u8,
    user_entered_samples_excluded: bool,
) -> u16 {
    let exclusion_points: u16 = if user_entered_samples_excluded { 10 } else { 0 };

    (recency_bucket as u16) * 30
        + (continuity_bucket as u16) * 25
        + (source_confidence_bucket as u16) * 20
        + (signal_count_bucket as u16) * 15
        + exclusion_points
}

fn score_tier(score: u16, threshold_score: u16, high_threshold_score: u16) -> u8 {
    if score >= high_threshold_score {
        2
    } else if score >= threshold_score {
        1
    } else {
        0
    }
}

fn toy_feature_commitment(
    challenge_hash: Field,
    policy_version: Field,
    recency_bucket: u8,
    continuity_bucket: u8,
    source_confidence_bucket: u8,
    signal_count_bucket: u8,
    user_entered_samples_excluded: bool,
) -> Field {
    let excluded_flag: Field = if user_entered_samples_excluded { 1 } else { 0 };

    challenge_hash
        + policy_version * 17
        + (recency_bucket as Field) * 101
        + (continuity_bucket as Field) * 1009
        + (source_confidence_bucket as Field) * 10007
        + (signal_count_bucket as Field) * 100003
        + excluded_flag * 1000003
}
