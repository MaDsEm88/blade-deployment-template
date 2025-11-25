import { model, string } from 'blade/schema';


export const Account = model({
  slug: "account",
  fields: {
    handle: string({ unique: true }),
    email: string({ unique: true }),
   
  },
})