import type { CourierApproval } from '../services/blockchain';

export function parseCourierApprovalPayload(
  input: unknown
): CourierApproval | undefined {
  if (input === undefined || input === null) {
    return undefined;
  }

  if (typeof input !== 'object') {
    throw new Error(
      'courierApproval must be an object with deadline and signature fields'
    );
  }

  const { signature, deadline } = input as {
    signature?: unknown;
    deadline?: unknown;
  };

  if (typeof signature !== 'string' || !signature.trim()) {
    throw new Error(
      'courierApproval.signature must be a non-empty string'
    );
  }

  if (
    deadline === undefined ||
    deadline === null ||
    (typeof deadline === 'string' && !deadline.trim())
  ) {
    throw new Error('courierApproval.deadline is required');
  }

  if (
    typeof deadline !== 'number' &&
    typeof deadline !== 'string' &&
    typeof deadline !== 'bigint'
  ) {
    throw new Error(
      'courierApproval.deadline must be a number, string, or bigint'
    );
  }

  return {
    signature: signature.trim(),
    deadline,
  };
}
