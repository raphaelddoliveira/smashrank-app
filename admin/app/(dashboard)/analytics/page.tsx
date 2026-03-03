import { Header } from '@/components/header'
import {
  getUserGrowthCumulative,
  getChallengesByClubMonthly,
  getClubComparison,
} from '@/lib/queries/analytics'
import { AnalyticsCharts } from './analytics-charts'

export const dynamic = 'force-dynamic'

export default async function AnalyticsPage() {
  const [userGrowth, challengesByClub, clubComparison] = await Promise.all([
    getUserGrowthCumulative(),
    getChallengesByClubMonthly(),
    getClubComparison(),
  ])

  return (
    <>
      <Header title="Analytics" subtitle="Graficos de evolucao e comparacao" />

      <AnalyticsCharts
        userGrowth={userGrowth}
        challengesByClub={challengesByClub}
        clubComparison={clubComparison}
      />
    </>
  )
}
