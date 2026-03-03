import { Header } from '@/components/header'
import { getClubsList } from '@/lib/queries/clubs'
import { ClubsTable } from './clubs-table'

export const dynamic = 'force-dynamic'

export default async function ClubsPage() {
  const clubs = await getClubsList()

  return (
    <>
      <Header title="Clubes" subtitle={`${clubs.length} clube(s) cadastrado(s)`} />
      <ClubsTable clubs={clubs} />
    </>
  )
}
