select
    campaign_id,
    campaign_name,
    campaign_type,
    channel,
    start_date,
    end_date,
    budget,
    target_audience,
    expected_impressions,
    actual_impressions,
    clicks,
    conversions,
    status
from {{ source('raw', 'marketing_campaigns') }}
