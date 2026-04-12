const fetch = globalThis.fetch
const MGMT = 'sbp_8219ec827fa5581a888bb317f149fa522b08ffd1'
const PROJECT = 'cmswoyiuoeqzeassubvw'

async function runSQL(sql) {
  const r = await fetch(`https://api.supabase.com/v1/projects/${PROJECT}/database/query`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${MGMT}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: sql })
  })
  return r.json()
}

async function main() {
  // Drop + Recreate execute_withdrawal
  await runSQL(`DROP FUNCTION IF EXISTS execute_withdrawal(UUID, UUID, NUMERIC, JSONB, TEXT) CASCADE;`)

  await runSQL(`
    CREATE OR REPLACE FUNCTION execute_withdrawal(
      p_account_id UUID,
      p_to_account_id UUID,
      p_amount NUMERIC(12,2),
      p_fee_detail JSONB DEFAULT '{}',
      p_remark TEXT DEFAULT NULL
    ) RETURNS JSONB AS $$
    DECLARE
      v_actual_arrival NUMERIC(12,2);
      v_new_balance NUMERIC(12,2);
      v_to_balance NUMERIC(12,2);
      v_wid UUID;
    BEGIN
      v_actual_arrival := p_amount - (
        COALESCE((p_fee_detail->>'technical_fee')::NUMERIC, 0) +
        COALESCE((p_fee_detail->>'payment_fee')::NUMERIC, 0) +
        COALESCE((p_fee_detail->>'withdraw_fee')::NUMERIC, 0) +
        COALESCE((p_fee_detail->>'other_fee')::NUMERIC, 0)
      );
      UPDATE accounts SET balance = balance - p_amount, updated_at = NOW()
        WHERE id = p_account_id RETURNING balance INTO v_new_balance;
      UPDATE accounts SET balance = balance + v_actual_arrival, updated_at = NOW()
        WHERE id = p_to_account_id RETURNING balance INTO v_to_balance;
      INSERT INTO withdrawals (account_id, to_account_id, amount, fee_detail, actual_arrival, status, withdrawn_at, remark)
        VALUES (p_account_id, p_to_account_id, p_amount, p_fee_detail, v_actual_arrival, 'completed', NOW(), p_remark)
        RETURNING id INTO v_wid;
      RETURN jsonb_build_object('success', true, 'withdrawal_id', v_wid, 'actual_arrival', v_actual_arrival);
    END;
    $$ LANGUAGE plpgsql;
  `)

  // Trigger schema reload
  await runSQL(`NOTIFY pgrst, 'reload schema';`)
  console.log('Done')
}

main()
