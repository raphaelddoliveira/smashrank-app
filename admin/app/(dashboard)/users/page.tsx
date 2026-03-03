import { Header } from '@/components/header'
import { getUsersList } from '@/lib/queries/users'
import { UsersTable } from './users-table'

export const dynamic = 'force-dynamic'

export default async function UsersPage() {
  const users = await getUsersList()

  return (
    <>
      <Header title="Usuarios" subtitle={`${users.length} usuario(s) cadastrado(s)`} />
      <UsersTable users={users} />
    </>
  )
}
