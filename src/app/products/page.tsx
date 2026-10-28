import { createAdminClient } from '@/lib/supabase/server';
import { ProductsManager } from '@/components/products-manager';

export const dynamic = 'force-dynamic';

export default async function ProductsPage() {
  const supabase = await createAdminClient();

  const { data: products } = await supabase
    .from('products')
    .select('*')
    .order('sort', { ascending: true });

  return <ProductsManager products={products || []} />;
}
