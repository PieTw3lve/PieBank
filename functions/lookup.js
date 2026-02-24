const { app } = require('@azure/functions');
const sql = require('mssql');

app.http('lookup', {
    methods: ['POST'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        let body;

        try {
            body = await request.json();
        } catch {
            return {
                status: 400,
                jsonBody: {
                    success: false,
                    error: 'Invalid JSON in request body'
                }
            };
        }

        const { tx_id, key } = body;

        if (key !== process.env.GATEWAY_SECRET) {
            return {
                status: 401,
                jsonBody: {
                    success: false,
                    error: 'Invalid authentication key'
                }
            };
        }

        if (!tx_id) {
            return {
                status: 400,
                jsonBody: {
                    success: false,
                    error: 'The tx_id field is required'
                }
            };
        }

        try {
            await sql.connect(process.env.SQL_CONNECTION_STRING);

            const result = await sql.query`
                SELECT owner
                FROM user_accounts
                WHERE tx_id = ${tx_id}
            `;

            if (result.recordset.length === 0) {
                return {
                    jsonBody: {
                        success: false,
                        error: 'Bank account not found'
                    }
                };
            }

            const account = result.recordset[0];

            return {
                jsonBody: {
                    success: true,
                    owner: account.owner
                }
            };

        } catch (err) {
            context.log(err);
            return {
                status: 500,
                jsonBody: {
                    success: false,
                    error: 'An internal server error occurred'
                }
            };
        }
    }
});